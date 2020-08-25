import Foundation
import CZeroMQ


/// Called by zmq when it is done with the buffer backing a message
/// - Parameters:
///   - pointer: Pointer to the buffer to be freed
///   - hint: Caller-provided hint (not required in Swift, but passed anyway)
fileprivate func free(pointer: UnsafeMutableRawPointer?, hint: UnsafeMutableRawPointer?) -> Void {
    pointer?.deallocate()
}

public final class Message {
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

    public convenience init(_ string: String, encoding: String.Encoding = .utf8) throws {
        guard let data = string.data(using: encoding) else {
            throw ZMQError.stringCouldNotBeEncoded(string)
        }
        try self.init(data)
    }

    public init(_ data: Data) throws {
        let byteCount = data.count

        message = try data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> zmq_msg_t in
            let copy = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: 8)
            copy.copyMemory(from: bytes.baseAddress!, byteCount: byteCount)
            var message = zmq_msg_t()

            if zmq_msg_init_data(&message, copy, byteCount, free, nil) == -1 {
                throw ZMQError.lastError()
            }

            return message
        }
    }

    @available(*, deprecated, message: "The init implementations taking String or Data are your friends")
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

    deinit {
        zmq_msg_close(&message)
    }

    public var data: UnsafeMutableRawPointer {
        return zmq_msg_data(&message)
    }

    public var size: Int {
        return zmq_msg_size(&message)
    }
}

public extension Message {
    func toString(encoding: String.Encoding = .utf8) -> String? {
        let data = Data(bytes: self.data, count: self.size)
        return String(data: data, encoding:encoding)
    }

    static func from(string: String, encoding: String.Encoding = .utf8) -> Message? {
        return string.asZmqMessage(encoding: encoding)
    }
}

public extension String {
    func asZmqMessage(encoding: String.Encoding = .utf8) -> Message? {
        guard let data = self.data(using:encoding) else { return nil }

        return try? Message(data)
    }
}
