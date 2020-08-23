import Foundation
import CZeroMQ

public class Socket {
    private var socket: UnsafeMutableRawPointer?


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

    /// Closes the socket
    /// - Throws: If the socket was already NULL (can't happen)
    public func close() throws {
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
    public func bind(to endpoint: String) throws {
        guard let socket = socket else {
            fatalError("Tried to bind a non-existant socket")
        }
        let result = zmq_bind(socket, endpoint)

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
    public func connect(to endpoint: String) throws {
        guard let socket = socket else {
            fatalError("Tried to connect from a non-existant socket")
        }
        let result = zmq_connect(socket, endpoint)

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
    public func send(data: Data, options: SocketSendRecvOption) -> Result<Void, Error> {
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

    deinit {
        do {
            try close()
        } catch {
            print(error)
        }
    }
}
