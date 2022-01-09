import Foundation
import CZeroMQ

// TO-DO: We really want a way of returning typed-sockets, that only expose functionality
//        appropriate for the socket type
//        (e.g. a publisher can't subscribe, a push can't pull etc.)

public class Socket {
    var socket: UnsafeMutableRawPointer?

    /// Attempts to create a new socket of the specified type
    /// - Parameters:
    ///   - context: The containing context
    ///   - type: One of the supported socket types (req/rep, push/pull etc.)
    /// - Throws: When it is not possible to create the socket, due to:
    ///     * Invalid context
    ///     * Invalid socket type
    ///     * Maximum number of sockets already open
    ///     * The context was terminated
    public init(context: UnsafeMutableRawPointer?, type: SocketType) throws {
        guard let socket =  zmq_socket(context, type.rawValue) else {
            throw ZMQError.lastError()
        }

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

    /// Attempts to bind the socket to an endpoint.
    ///
    /// Endpoints can be of the form:
    ///  * tcp://interface:portnumber (see `man zmq_tcp`)
    ///  * ipc://whatever (see `man zmq_ipc`)
    ///  * inproc://somename - in-process (see `man zmq_inproc`)
    ///
    ///  For tcp connections, the interface should be one of:
    ///  * * - wildcard meaning "all available interfaces"
    ///  * The primary address (IPv4 or IPv6) of the interface, in *numeric* form
    ///  * The non-portable interface name as defined by the operating system (e.g. "eth0")
    /// - Parameter endpoint: The endpoint to bind to
    /// - Throws: When binding fails, generally due to the port being in use, or the transport being invalid
    public func bind(to endpoint: Endpoint) throws {
        guard let socket = socket else {
            fatalError("Tried to bind a non-existant socket")
        }
        let result = zmq_bind(socket, endpoint.path)

        if result == -1 {
            throw ZMQError.lastError()
        }
    }

    /// Attempts to connect to the specified endpoint
    ///
    /// Endpoints can be of the form:
    ///  * tcp://address:portnumber (see `man zmq_tcp`)
    ///  * ipc://whatever (see `man zmq_ipc`)
    ///  * inproc://somename - in-process (see `man zmq_inproc`)
    ///
    ///  For tcp connections, the address should be one of:
    ///  * The DNS name of the peer
    ///  * The primary address (IPv4 or IPv6) of the interface, in *numeric* form
    /// - Parameter endpoint: What to connect to
    /// - Throws: When
    public func connect(to endpoint: Endpoint) throws {
        guard let socket = socket else {
            fatalError("Tried to connect from a non-existant socket")
        }
        let result = zmq_connect(socket, endpoint.path)

        if result == -1 {
            throw ZMQError.lastError()
        }
    }

    /// Attempts to send the provided data, applying the specified options
    /// - Parameters:
    ///   - data: The data to send
    ///   - options: One of .none, .dontWait, .sendMore, .dontWaitSendMore
    /// - Returns: A result confirming success or reporting any error
    @discardableResult
    public func send(_ data: Data, options: SocketSendRecvOption = .none) -> Result<Void, Error> {
        data.withUnsafeBytes { rawBufferPointer in
            let result = zmq_send(socket!, rawBufferPointer.baseAddress, data.count, options.rawValue)

            if result == -1 {
                return .failure(ZMQError.lastError())
            }

            return .success(())
        }
    }

    /// Attempts to receive data of the specified size
    /// - Parameter size: The expected byte count
    /// - Returns: A result containing either the received data or and error describing any failure
    public func receive(size: Int, options: SocketSendRecvOption = .none) -> Result<Data, Error> {
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: size)
        defer { buffer.deallocate() }

        let received = zmq_recv(socket!, buffer, size, options.rawValue)

        if received == -1 {
            return .failure(ZMQError.lastError())
        }

        return .success(Data(bytes: buffer, count: Int(received)))
    }

    public func receiveMessage(options: SocketSendRecvOption = .none) -> Result<Data, Error> {
        var msg = zmq_msg_t()
        defer { zmq_msg_close(&msg) }

        guard zmq_msg_init(&msg) == 0 else {
            return .failure(ZmqError(errNo: errno))
        }

        guard zmq_msg_recv(&msg, socket, options.rawValue) != -1 else {
            return .failure(ZmqError(errNo: errno))
        }

        guard let buffer = zmq_msg_data(&msg) else {
            return .failure(ZmqError(errNo: errno))
        }
        let size = zmq_msg_size(&msg)

        return .success(Data(bytes: buffer, count: size))
    }

    struct ZmqError: Error {
        let errNo: Int32
    }

    /// Receive all parts of a message, returning the result as [Data]
    /// - Parameter options:
    /// - Returns:
    public func receive() -> Result<[Data], Error> {
        var more: Int = 1
        var moreSize = MemoryLayout<Int>.size
        var msg = zmq_msg_t()

        defer { zmq_msg_close(&msg) }

        guard zmq_msg_init(&msg) == 0 else {
            return .failure(ZmqError(errNo: errno))
        }

        var parts = [Data]()

        while more != 0 {
            guard zmq_msg_recv(&msg, socket, 0) != -1 else {
                return .failure(ZmqError(errNo: errno))
            }

            guard let buffer = zmq_msg_data(&msg) else {
                return .failure(ZmqError(errNo: errno))
            }
            let size = zmq_msg_size(&msg)

            let part = Data(bytes: buffer, count: size)
            parts.append(part)

            if zmq_getsockopt(socket, ZMQ_RCVMORE, &more, &moreSize) != 0 {
                return .failure(ZmqError(errNo: errno))
            }
        }

        return .success(parts)
    }

    public func subscribe(to topic: String = "") throws {
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

// MARK: - String conveniences
extension Socket {
    @discardableResult
    public func send(_ string: String, options: SocketSendRecvOption = .none) -> Result<Void, Error> {
        guard let data = string.data(using: .utf8) else {
            return .failure(ZMQError.stringCouldNotBeEncoded(string))
        }

        return send(data, options: options)
    }

    public func receive(size: Int, options: SocketSendRecvOption = .none) -> Result<String, Error> {
        return receive(size: size, options: options).flatMap { (data: Data) in
            guard let msg = String(data: data, encoding: .utf8) else {
                return .failure(ZMQError.invalidUTF8String)
            }
            return .success(msg)
        }
    }

    public func receiveMessage(options: SocketSendRecvOption = .none) -> Result<String, Error> {
        return receiveMessage(options: options).flatMap { (data: Data) in
            guard let msg = String(data: data, encoding: .utf8) else {
                return .failure(ZMQError.invalidUTF8String)
            }
            return .success(msg)
        }
    }
}
