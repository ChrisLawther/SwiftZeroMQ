import Foundation
import CZeroMQ

enum ZMQError: Error {

    case stringCouldNotBeEncoded(String)
    case invalidUTF8String

    case other(description: String)

    static func lastError(file: String = #file, line: Int = #line ) -> Error {
        let description = String(validatingUTF8: zmq_strerror(zmq_errno()))!
        return ZMQError.other(description: description)
    }

}

extension ZMQError: CustomStringConvertible {
    var description: String {
        switch self {
        case .stringCouldNotBeEncoded(let string):
            return "Could not encode '\(string)' as data"
        case .invalidUTF8String:
            return "Data did not represent a valid UTF8 string"
        case .other(description: let description):
            return description
        }
    }
}
