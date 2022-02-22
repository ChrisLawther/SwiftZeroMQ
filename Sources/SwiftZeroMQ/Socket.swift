import Foundation
import CZeroMQ

// MARK: - Read/write/connect/bind/subscribe/publish protocols

public protocol ConnectableSocket {
    func connect(to: Endpoint) throws
}

public protocol BindableSocket {
    func bind(to: Endpoint) throws
}

public struct Address {
    let sender: Data
}

public protocol AddressableSocket {
    func receiveMessage() throws -> (Address, Data)
    func sendMessage(to: Address, data: Data) throws -> Void
}

protocol SocketCommon {
    func close() throws
}

public protocol ReadableSocket: ConnectableSocket, BindableSocket {
    func receiveMessage(options: SocketSendRecvOption) throws -> Data
    func receiveMultipartMessage() throws -> [Data]
    func on(_ identifier: Data, handler: @escaping ([Data]) -> Void)
    func on(flags: PollingFlags, handler: @escaping (Socket) -> Void)
}

extension ReadableSocket {
    public func receiveStringMessage(options: SocketSendRecvOption = .none) throws -> String {
        let data = try receiveMessage(options: options)

        guard let message = String(data: data, encoding: .utf8) else {
            throw ZMQError.invalidUTF8String
        }
        return message
    }

    public func on(_ identifier: String, handler: @escaping ([Data]) -> Void) throws {
        guard let data = identifier.data(using: .utf8) else {
            throw ZMQError.stringCouldNotBeEncoded(identifier)
        }
        on(data, handler: handler)
    }

    public func on<T: MessageIdentifiable>(_ type: T.Type = T.self, handler: @escaping (T) -> Void) throws -> Void {
        try on(type.identifier) { data in
            let message = T.init(data[0])
            handler(message)
        }
    }
}

public protocol WriteableSocket: ConnectableSocket, BindableSocket {
    func send(_ data: Data, options: SocketSendRecvOption) throws -> Void
}

extension WriteableSocket {
    public func send(_ data: [Data]) throws -> Void {
        for packet in data[0..<(data.count-1)] {
            try send(packet, options: .dontWaitSendMore)
        }
        if let final = data.last {
            try send(final, options: .dontWait)
        }
    }

    /// Send the provided data
    /// - Throws Underlying ZMQ error when data could not be sent
    public func send(_ message: String, options: SocketSendRecvOption = .none) throws -> Void {
        guard let data = message.data(using: .utf8) else {
            throw ZMQError.stringCouldNotBeEncoded(message)
        }
        try send(data, options: options)
    }

    public func send(_ fragments: [String]) throws -> Void {
        let packets = try fragments.map { fragment -> Data in
            guard let data = fragment.data(using: .utf8) else {
                throw ZMQError.stringCouldNotBeEncoded(fragment)
            }
            return data
        }
        try send(packets)
    }
}

public protocol PublisherSocket: WriteableSocket { }

extension PublisherSocket {
    func publish(topic: String, data: Data) throws -> Void {
        try send([topic.data(using: .utf8)!, data])
    }
}

public typealias RequestSocket = ReadableSocket & WriteableSocket
public typealias ReplySocket = ReadableSocket & WriteableSocket
public typealias DealerSocket = ReadableSocket & WriteableSocket
public typealias RouterSocket = ReadableSocket & AddressableSocket

public protocol SubscriberSocket: ReadableSocket {
    func subscribe(to: Data) throws
}

public extension SubscriberSocket {
    func subscribe(to topic: String) throws {
        guard let bytes = topic.data(using: .utf8) else {
            // TODO: Throw "invalidTopicError" ?
            return
        }
        try subscribe(to: bytes)
    }
}

public extension SubscriberSocket {
    func subscribe() throws {
        try subscribe(to: "")
    }
}

struct ZmqError: Error, LocalizedError {
    let errNo: Int32
    var errorDescription: String { String(cString: zmq_strerror(errNo)) }
}

// MARK: - Socket

public class Socket {
    var socket: UnsafeMutableRawPointer?
    let context: ZMQ

    /// Attempts to create a new socket of the specified type
    /// - Parameters:
    ///   - zmq: The parent context
    ///   - socket: The underlying zmq socket
    init(zmq: ZMQ, socket: UnsafeMutableRawPointer) {
        self.context = zmq
        self.socket = socket
    }

    deinit {
        do {
            try close()
        } catch {
            print(error)
        }
    }

    /// Closes the socket
    /// - Throws: If the socket was already NULL (can't happen?)
    func close() throws {
        guard let socket = socket else { return }

        let result = zmq_close(socket)

        if result == -1 {
            throw ZMQError.lastError()
        } else {
            // Success
            self.socket = nil
        }
    }
}

// MARK: - ReadableSocket

extension Socket: ReadableSocket {
    // Polling
    public func on(flags: PollingFlags, handler: @escaping (Socket) -> Void) {
        context.on(flags, for: self, handler: handler)
    }
    // Identifiable message routing
    public func on(_ identifier: Data, handler: @escaping ([Data]) -> Void) {
        context.on(identifier, from: self, handler: handler)
    }

    public func receiveMessage(options: SocketSendRecvOption) throws -> Data {
        var msg = zmq_msg_t()
        defer { zmq_msg_close(&msg) }

        guard zmq_msg_init(&msg) == 0 else {
            throw ZmqError(errNo: errno)
        }

        guard zmq_msg_recv(&msg, socket, options.rawValue) != -1 else {
            throw ZmqError(errNo: errno)
        }

        guard let buffer = zmq_msg_data(&msg) else {
            throw ZmqError(errNo: errno)
        }
        let size = zmq_msg_size(&msg)

        return Data(bytes: buffer, count: size)
    }

    public func receiveMultipartMessage() throws -> [Data] {
        var msg = zmq_msg_t()
        defer { zmq_msg_close(&msg) }

        guard zmq_msg_init(&msg) == 0 else {
            throw ZmqError(errNo: errno)
        }

        var more = 1
        var moreSize = MemoryLayout<Int>.size
        var parts = [Data]()

        while more != 0 {
            guard zmq_msg_recv(&msg, socket, 0) != -1 else {
                throw ZmqError(errNo: errno)
            }

            guard let buffer = zmq_msg_data(&msg) else {
                throw ZmqError(errNo: errno)
            }
            let size = zmq_msg_size(&msg)

            let part = Data(bytes: buffer, count: size)
            parts.append(part)

            // Are there more parts to *this* message?
            // (*not* are there more messages)
            if zmq_getsockopt(socket, ZMQ_RCVMORE, &more, &moreSize) != 0 {
                throw ZmqError(errNo: errno)
            }
        }

        return parts
    }
}

// MARK: - WriteableSocket

extension Socket: WriteableSocket {
    public func send(_ data: Data, options: SocketSendRecvOption) throws {
        try data.withUnsafeBytes { rawBufferPointer -> Void in
            let result = zmq_send(socket!, rawBufferPointer.baseAddress, data.count, options.rawValue)

            if result == -1 {
                throw ZMQError.lastError()
            }
        }
    }
}

extension Socket: PublisherSocket { }

// MARK: - BindableSocket

extension Socket: BindableSocket {
    public func bind(to endpoint: Endpoint) throws {
        guard let socket = socket else {
            fatalError("Tried to bind a non-existant socket")
        }
        let result = zmq_bind(socket, endpoint.path)

        if result == -1 {
            throw ZMQError.lastError()
        }
    }
}

// MARK: - ConnectableSocket

extension Socket: ConnectableSocket {
    public func connect(to endpoint: Endpoint) throws {
        guard let socket = socket else {
            fatalError("Tried to connect from a non-existant socket")
        }
        let result = zmq_connect(socket, endpoint.path)

        if result == -1 {
            throw ZMQError.lastError()
        }
    }
}

// MARK: - SubscriberSocket

extension Socket: SubscriberSocket {
    public func subscribe(to topic: Data) throws {
        guard let socket = socket else {
            fatalError("Tried to connect from a non-existant socket")
        }

        let result = topic.withUnsafeBytes { unsafeRawBufferPointer in
            return zmq_setsockopt(socket, ZMQ_SUBSCRIBE, unsafeRawBufferPointer.baseAddress, topic.count)
        }

        if result == -1 {
            throw ZMQError.lastError()
        }
    }
}

extension Socket: AddressableSocket {
    public func receiveMessage() throws -> (Address, Data) {
        let data: [Data] = try receiveMultipartMessage()
//        print("RX: \(data.count) parts")
        // Q. Should the payload be data.dropFirst() ?
        return (Address(sender: data[0]), data[1])
    }

    public func sendMessage(to address: Address, data: Data) throws {
        try send([address.sender, data])
    }
}

extension Socket: Hashable {
    public static func == (lhs: Socket, rhs: Socket) -> Bool {
        return lhs.socket == rhs.socket
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self).hashValue)
    }
}
