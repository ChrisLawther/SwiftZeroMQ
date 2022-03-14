import Foundation
import CZeroMQ

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
