import Foundation
import CZeroMQ

public func zmqVersion() -> (major: Int, minor: Int, patch: Int, versionString: String) {
    var major: Int32 = 0
    var minor: Int32 = 0
    var patch: Int32 = 0
    zmq_version(&major, &minor, &patch)
    let versionString = "\(major).\(minor).\(patch)"
    return (Int(major), Int(minor), Int(patch), versionString)
}

public final class ZMQ {
    private var context: UnsafeMutableRawPointer?
    private let worker: Worker

    public init(worker: Worker = DispatchQueue.global(qos: .utility)) throws {
        guard let context = zmq_ctx_new() else {
            throw ZMQError.lastError()
        }

        self.worker = worker

        self.context = context
    }

    public func socket(type: SocketType) throws -> Socket {
        return try Socket(context: self.context, type: type)
    }

    public func shutdown() throws {
        guard let context = context else { return }

        let result = zmq_ctx_shutdown(context)

        if result == -1 {
            throw ZMQError.lastError()
        } else {
            // Success
            self.context = nil
        }
    }

    deinit {
        guard let context = context else { return }

        let result = zmq_ctx_term(context)

        if result == -1 {
            print("Fail")
        } else {
            // Success
        }
    }
}
