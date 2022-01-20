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

    // MARK: - Req/rep
    public func requestSocket()  throws -> RequestSocket {
        return try Socket(context: context, type: .request)
    }

    public func replySocket()  throws -> ReplySocket {
        return try Socket(context: context, type: .reply)
    }

    // MARK: - Pub/sub
    public func publisherSocket()  throws -> WriteableSocket {
        return try Socket(context: context, type: .publish)
    }

    public func subscriberSocket()  throws -> SubscriberSocket {
        return try Socket(context: context, type: .subscribe)
    }
//
//    // MARK: - Push/pull
//    func pushSocket()  throws -> WriteableSocket {
//        return try Socket(context: context, type: .push)
//    }
//
//    func pullSocket()  throws -> ReadableSocket {
//        return try Socket(context: context, type: .pull)
//    }
//
//    // MARK: - Dealer/router
//    func dealerSocket() throws -> WriteableSocket {
//        return try Socket(context: context, type: .dealer)
//    }
//
//    func routerSocket() throws -> AddressableSocket  {
//        return try Socket(context: context, type: .router)
//    }

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
