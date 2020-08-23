import Foundation
import CZeroMQ

public class Socket {
    private var socket: UnsafeMutableRawPointer?

    public init(context: UnsafeMutableRawPointer?, type: SocketType) throws {
        guard let socket =  zmq_socket(context, type.rawValue) else {
            throw ZMQError.lastError
        }

        self.socket = socket
    }

    public func close() throws {
        guard let socket = socket else { return }

        let result = zmq_close(socket)

        if result == -1 {
            throw ZMQError.lastError
        } else {
            // Success
            self.socket = nil
        }
    }

    public func bind(to endpoint: String) throws {
        guard let socket = socket else {
            fatalError("Tried to bind a non-existant socket")
        }
        let result = zmq_bind(socket, endpoint)

        if result == -1 {
            throw ZMQError.lastError
        }
    }

    public func connect(to endpoint: String) throws {
        guard let socket = socket else {
            fatalError("Tried to connect from a non-existant socket")
        }
        let result = zmq_connect(socket, endpoint)

        if result == -1 {
            throw ZMQError.lastError
        }
    }

    public func send(data: Data, options: SocketSendRecvOption) -> Result<Void, Error> {
        data.withUnsafeBytes { rawBufferPointer in
            let result = zmq_send(socket!, rawBufferPointer.baseAddress, data.count, options.rawValue)

            if result == -1 {
                return .failure(ZMQError.lastError)
            }

            return .success(())
        }
    }

    public func receive(size: Int) -> Result<Data, Error> {
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: size)
        defer { buffer.deallocate() }

        let received = zmq_recv(socket!, buffer, size, 0)

        if received == -1 {
            return .failure(ZMQError.lastError)
        }

        return .success(Data(bytes: buffer, count: Int(received)))
    }

    deinit {
        do {
            try close()
        } catch {
            print(error)
        }
    }
}

public enum SocketType: Int32 {
    case request
    case reply
    case router
    case dealer

    case publish
    case subscribe
    case xpublish
    case xsubscribe

    case push
    case pull

    case pair

    case stream

    public var rawValue: Int32 {
        switch self {
        case .request:  return ZMQ_REQ
        case .reply:    return ZMQ_REP
        case .router:   return ZMQ_ROUTER
        case .dealer:   return ZMQ_DEALER

        case .publish:  return ZMQ_PUB
        case .subscribe: return ZMQ_SUB
        case .xpublish: return ZMQ_XPUB
        case .xsubscribe: return ZMQ_XSUB

        case .push:     return ZMQ_PUSH
        case .pull:     return ZMQ_PULL

        case .pair:     return ZMQ_PAIR

        case .stream:   return ZMQ_STREAM
        }
    }
}

public enum SocketSendRecvOption: Int32 {
    case none
    case dontWait
    case sendMore
    case dontWaitSendMore

    // Looks pointless, but `#define`d values aren't visible to `case xxx = whatever`
    // whereas they are visible in this context:
    public var rawValue: Int32 {
        switch self {
            case .none: return 0
            case .dontWait: return ZMQ_DONTWAIT
            case .sendMore: return ZMQ_SNDMORE
            case .dontWaitSendMore: return ZMQ_DONTWAIT | ZMQ_SNDMORE
        }
    }
}
