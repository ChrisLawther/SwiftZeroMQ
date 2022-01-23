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
    /// Send the provided data
    /// - Throws Underlying ZMQ error when data could not be sent
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

public typealias RequestSocket = ReadableSocket & WriteableSocket
public typealias ReplySocket = ReadableSocket & WriteableSocket

public protocol SubscriberSocket: ReadableSocket {
    func subscribe(to: String) throws
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
    public func subscribe(to topic: String) throws {
        guard let socket = socket else {
            fatalError("Tried to connect from a non-existant socket")
        }

        guard let bytes = topic.data(using: .utf8) else {
            return
        }
        let result = bytes.withUnsafeBytes { unsafeRawBufferPointer in
            return zmq_setsockopt(socket, ZMQ_SUBSCRIBE, unsafeRawBufferPointer.baseAddress, bytes.count)
        }
        if result == -1 {
            throw ZMQError.lastError()
        }
    }
}

//
//
//// MARK: - Bindable socket
//extension Socket: BindableSocket {
//    /// Attempts to bind the socket to an endpoint.
//    ///
//    /// Endpoints can be of the form:
//    ///  * tcp://interface:portnumber (see `man zmq_tcp`)
//    ///  * ipc://whatever (see `man zmq_ipc`)
//    ///  * inproc://somename - in-process (see `man zmq_inproc`)
//    ///
//    ///  For tcp connections, the interface should be one of:
//    ///  * * - wildcard meaning "all available interfaces"
//    ///  * The primary address (IPv4 or IPv6) of the interface, in *numeric* form
//    ///  * The non-portable interface name as defined by the operating system (e.g. "eth0")
//    /// - Parameter endpoint: The endpoint to bind to
//    /// - Throws: When binding fails, generally due to the port being in use, or the transport being invalid
//    public func bind(to endpoint: Endpoint) throws {
//        guard let socket = socket else {
//            fatalError("Tried to bind a non-existant socket")
//        }
//        let result = zmq_bind(socket, endpoint.path)
//
//        if result == -1 {
//            throw ZMQError.lastError()
//        }
//    }
//
//}
//
//// MARK: - Connectable socket
//extension Socket: ConnectableSocket {
//    /// Attempts to connect to the specified endpoint
//    ///
//    /// Endpoints can be of the form:
//    ///  * tcp://address:portnumber (see `man zmq_tcp`)
//    ///  * ipc://whatever (see `man zmq_ipc`)
//    ///  * inproc://somename - in-process (see `man zmq_inproc`)
//    ///
//    ///  For tcp connections, the address should be one of:
//    ///  * The DNS name of the peer
//    ///  * The primary address (IPv4 or IPv6) of the interface, in *numeric* form
//    /// - Parameter endpoint: What to connect to
//    /// - Throws: When
//    public func connect(to endpoint: Endpoint) throws {
//        guard let socket = socket else {
//            fatalError("Tried to connect from a non-existant socket")
//        }
//        let result = zmq_connect(socket, endpoint.path)
//
//        if result == -1 {
//            throw ZMQError.lastError()
//        }
//    }
//}
//
//public extension Socket {
//
//    /// Attempts to send the provided data, applying the specified options
//    /// - Parameters:
//    ///   - data: The data to send
//    ///   - options: One of .none, .dontWait, .sendMore, .dontWaitSendMore
//    /// - Returns: A result confirming success or reporting any error
////    @discardableResult
////    public func send(_ data: Data, options: SocketSendRecvOption = .none) -> Result<Void, Error> {
////        data.withUnsafeBytes { rawBufferPointer in
////            let result = zmq_send(socket!, rawBufferPointer.baseAddress, data.count, options.rawValue)
////
////            if result == -1 {
////                return .failure(ZMQError.lastError())
////            }
////
////            return .success(())
////        }
////    }
//
//    func send(_ data: Data, options: SocketSendRecvOption) throws -> Void {
//        try data.withUnsafeBytes { rawBufferPointer in
//            let result = zmq_send(socket!, rawBufferPointer.baseAddress, data.count, options.rawValue)
//
//            if result == -1 {
//                throw ZMQError.lastError()
//            }
//        }
//    }
//
//    /// Attempts to receive data of the specified size
//    /// - Parameter size: The expected byte count
//    /// - Returns: A result containing either the received data or and error describing any failure
//    func receive(size: Int, options: SocketSendRecvOption = .none) -> Result<Data, Error> {
//        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: size)
//        defer { buffer.deallocate() }
//
//        let received = zmq_recv(socket!, buffer, size, options.rawValue)
//
//        if received == -1 {
//            return .failure(ZMQError.lastError())
//        }
//
//        return .success(Data(bytes: buffer, count: Int(received)))
//    }
//
//    func receiveMessage(options: SocketSendRecvOption = .none) -> Result<Data, Error> {
//        var msg = zmq_msg_t()
//        defer { zmq_msg_close(&msg) }
//
//        guard zmq_msg_init(&msg) == 0 else {
//            return .failure(ZmqError(errNo: errno))
//        }
//
//        guard zmq_msg_recv(&msg, socket, options.rawValue) != -1 else {
//            return .failure(ZmqError(errNo: errno))
//        }
//
//        guard let buffer = zmq_msg_data(&msg) else {
//            return .failure(ZmqError(errNo: errno))
//        }
//        let size = zmq_msg_size(&msg)
//
//        return .success(Data(bytes: buffer, count: size))
//    }
//

//
//    /// Receive all parts of a message, returning the result as [Data]
//    /// - Parameter options:
//    /// - Returns:
//    func receive() -> Result<[Data], Error> {
//        var more: Int = 1
//        var moreSize = MemoryLayout<Int>.size
//        var msg = zmq_msg_t()
//
//        defer { zmq_msg_close(&msg) }
//
//        guard zmq_msg_init(&msg) == 0 else {
//            return .failure(ZmqError(errNo: errno))
//        }
//
//        var parts = [Data]()
//
//        while more != 0 {
//            guard zmq_msg_recv(&msg, socket, 0) != -1 else {
//                return .failure(ZmqError(errNo: errno))
//            }
//
//            guard let buffer = zmq_msg_data(&msg) else {
//                return .failure(ZmqError(errNo: errno))
//            }
//            let size = zmq_msg_size(&msg)
//
//            let part = Data(bytes: buffer, count: size)
//            parts.append(part)
//
//            // Are there more parts to *this* message?
//            // (*not* are there more messages)
//            if zmq_getsockopt(socket, ZMQ_RCVMORE, &more, &moreSize) != 0 {
//                return .failure(ZmqError(errNo: errno))
//            }
//        }
//
//        return .success(parts)
//    }
//}
//
//// MARK: Publisher / subscriber sockets
//extension Socket: SubscriberSocket {
//    public func subscribe(to topic: String = "") throws {
//        guard let socket = socket else {
//            fatalError("Tried to connect from a non-existant socket")
//        }
//
//        guard let bytes = topic.data(using: .utf8) else {
//            return
//        }
//        let result = bytes.withUnsafeBytes { unsafeRawBufferPointer in
//            return zmq_setsockopt(socket, ZMQ_SUBSCRIBE, unsafeRawBufferPointer.baseAddress, bytes.count)
//        }
//        if result == -1 {
//            throw ZMQError.lastError()
//        }
//    }
//}
//
//// MARK: Addressable socket - router sockets
//extension Socket: AddressableSocket {
//    public func receiveMessage() throws -> (Address, Data) {
//        var msg = zmq_msg_t()
//        defer { zmq_msg_close(&msg) }
//
//        guard zmq_msg_init(&msg) == 0 else {
//            throw ZmqError(errNo: errno)
//        }
//
//        guard zmq_msg_recv(&msg, socket, SocketSendRecvOption.none.rawValue) != -1 else {
//            throw ZmqError(errNo: errno)
//        }
//
//        guard let buffer = zmq_msg_data(&msg) else {
//            throw ZmqError(errNo: errno)
//        }
//
//        var size = zmq_msg_size(&msg)
//        let address = Address(sender: Data(bytes: buffer, count: size))
//
//        guard zmq_msg_recv(&msg, socket, SocketSendRecvOption.none.rawValue) != -1 else {
//            throw ZmqError(errNo: errno)
//        }
//
//        guard let buffer = zmq_msg_data(&msg) else {
//            throw ZmqError(errNo: errno)
//        }
//
//        size = zmq_msg_size(&msg)
//        let data = Data(bytes: buffer, count: size)
//
//        return (address, data)
//    }
//
//    public func sendMessage(to address: Address, data: Data) throws {
//        do {
//            try send(address.sender, options: .dontWaitSendMore)
//            try send(data, options: .dontWait)
//        }
//    }
//}
//
//// MARK: - String conveniences
//extension Socket: WriteableSocket {
//    public func send(_ string: String, options: SocketSendRecvOption = .none) throws {
//        guard let data = string.data(using: .utf8) else {
//            throw ZMQError.stringCouldNotBeEncoded(string)
//        }
//
//        try send(data, options: options)
//    }
//}
//
//extension ReadableSocket {
//    public func receive() throws -> String {
//        let data = try receiveMessage()
//        guard let message = String(data: data, encoding: .utf8) else {
//            throw ZMQError.invalidUTF8String
//        }
//        return message
//    }
////
////    public func receive(size: Int, options: SocketSendRecvOption = .none) -> Result<String, Error> {
////        return receive(size: size, options: options).flatMap { (data: Data) in
////            guard let msg = String(data: data, encoding: .utf8) else {
////                return .failure(ZMQError.invalidUTF8String)
////            }
////            return .success(msg)
////        }
////    }
////
//    public func receiveMessage(options: SocketSendRecvOption = .none) throws -> Data {
//        return receiveMessage(options: options).flatMap { (data: Data) in
//            guard let msg = String(data: data, encoding: .utf8) else {
//                return .failure(ZMQError.invalidUTF8String)
//            }
//            return .success(msg)
//        }
//    }
////
////    public func receiveMessage(options: SocketSendRecvOption = .none) -> Result<[String], Error> {
////        receive().flatMap { messages in
////            print("🧐 Received \(messages.count) Data messages")
////
////            let strings = messages.compactMap { msg in
////                String(data: msg, encoding: .utf8)
////            }
////
////            return .success(strings)
////        }
////    }
//}
