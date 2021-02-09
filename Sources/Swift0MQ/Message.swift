import Foundation
import CZeroMQ

/// Called by zmq when it is done with the buffer backing a message
/// - Parameters:
///   - pointer: Pointer to the buffer to be freed
///   - hint: Caller-provided hint (not required in Swift, but passed anyway)
fileprivate func free(pointer: UnsafeMutableRawPointer?,
                      hint: UnsafeMutableRawPointer?) -> Void {
    pointer?.deallocate()
}

public final class Message {
    private var message: zmq_msg_t


    /// Initializes an empty message, ready to receive inbound message data into
    /// - Throws: <#description#>
    init() throws {
        message = zmq_msg_t()

        if zmq_msg_init(&message) == -1 {
            throw ZMQError.lastError()
        }
    }


    /// Initializes a message with data copied from the provided String
    /// - Parameters:
    ///   - string: The String to use
    ///   - encoding: The encoding of the string (defaults to utf8)
    /// - Throws: If the string could not be encoded as data using the specified encoding
    public convenience init(_ string: String, encoding: String.Encoding = .utf8) throws {
        guard let data = string.data(using: encoding) else {
            throw ZMQError.stringCouldNotBeEncoded(string)
        }
        try self.init(data)
    }


    /// Initializes a message with a copy of the provided data, with it's deallocation correctly registered
    /// - Parameter data: The data
    /// - Throws: If the message could not be initialized
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

    deinit {
        zmq_msg_close(&message)
    }

    @available(*, deprecated, message: "Use `getData` to get a copy")
    public var data: UnsafeMutableRawPointer {
        return zmq_msg_data(&message)
    }

    @available(*, deprecated, message: "Use `getData` to get a copy")
    public var size: Int {
        return zmq_msg_size(&message)
    }

    public func getData() -> Data? {
        guard let ptr = zmq_msg_data(&message) else {
            return nil
        }

        let size = zmq_msg_size(&message)

        return Data(bytes: ptr, count: size)
    }
}

public extension Message {
    func asString(encoding: String.Encoding = .utf8) -> String? {
        guard let data = getData() else { return nil }
        
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
