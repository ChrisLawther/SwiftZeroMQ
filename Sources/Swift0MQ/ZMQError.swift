import Foundation
import CZeroMQ

struct ZMQError: Error, CustomStringConvertible {
    public let description: String

    static func lastError(file: String = #file, line: Int = #line ) -> Error {
        let description = String(validatingUTF8: zmq_strerror(zmq_errno()))!
        return ZMQError(description: description)
    }
}
