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
    private let poller: SocketPoller
    private let router: MessageRouter

    public static func standard() throws -> ZMQ {
        let worker = DispatchQueue.global(qos: .utility)
        let poller = SocketPoller(worker: worker)
        let router = MessageRouter(poller: poller)
        return try ZMQ(poller: poller, router: router)
    }

    init(poller: SocketPoller, router: MessageRouter) throws {
        guard let context = zmq_ctx_new() else {
            throw ZMQError.lastError()
        }

        self.context = context

        self.poller = poller
        self.router = router
    }

    private func makeSocket(type: SocketType) throws -> Socket {
        guard let socket =  zmq_socket(context, type.rawValue) else {
            throw ZMQError.lastError()
        }
        return Socket(zmq: self, socket: socket)
    }

    // MARK: - Req/rep
    public func requestSocket()  throws -> RequestSocket {
        return try makeSocket(type: .request)
    }

    public func replySocket()  throws -> ReplySocket {
        return try makeSocket(type: .reply)
    }

    // MARK: - Pub/sub
    public func publisherSocket()  throws -> WriteableSocket {
        return try makeSocket(type: .publish)
    }

    public func subscriberSocket()  throws -> SubscriberSocket {
        return try makeSocket(type: .subscribe)
    }
//
//    // MARK: - Push/pull
//    func pushSocket()  throws -> WriteableSocket {
//        return try makeSocket(type: .push)
//    }
//
//    func pullSocket()  throws -> ReadableSocket {
//        return try makeSocket(type: .pull)
//    }
//
//    // MARK: - Dealer/router
//    func dealerSocket() throws -> WriteableSocket {
//        return try makeSocket(type: .dealer)
//    }
//
//    func routerSocket() throws -> AddressableSocket  {
//        return try makeSocket(type: .router)
//    }


    public func on(_ identifier: Data,
                   from socket: Socket,
                   handler: @escaping ([Data]) -> Void) {
        print("🧐 Context registering socket for identified response")
        router.on(identifier: identifier, from: socket, handler: handler)
    }

    public func on(_ flags: PollingFlags,
                   for socket: Socket,
                   handler: @escaping (Socket) -> Void) {
        print("🧐 Context registering socket for polling")
        poller.poll(socket: socket, flags: flags, handler: handler)
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
