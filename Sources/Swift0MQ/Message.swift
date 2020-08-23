import Foundation
import CZeroMQ

final class Message {
    private var message: zmq_msg_t

    init() throws {
        message = zmq_msg_t()

        if zmq_msg_init(&message) == -1 {
            throw ZMQError.lastError()
        }
    }

    init(size: Int) throws {
        message = zmq_msg_t()

        if zmq_msg_init_size(&message, size) == -1 {
            throw ZMQError.lastError()
        }
    }

    public init(data: UnsafeMutableRawPointer,
                size: Int,
                hint: UnsafeMutableRawPointer? = nil,
                ffn: @escaping @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void) throws {
        message = zmq_msg_t()

        if zmq_msg_init_data(&message, data, size, ffn, hint) == -1 {
            throw ZMQError.lastError()
        }
    }

    public init(data: UnsafeMutableRawPointer, size: Int) throws {
        message = zmq_msg_t()

        if zmq_msg_init_data(&message, data, size, nil, nil) == -1 {
            throw ZMQError.lastError()
        }
    }
}
