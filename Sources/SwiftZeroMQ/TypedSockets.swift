import Foundation

protocol ConnectableSocket {
    func connect(to: Endpoint) throws
}

protocol BindableSocket {
    func bind(to: Endpoint) throws
}

public struct Address {
    let sender: Data
}

protocol AddressableSocket {
    func receiveMessage() throws -> (Address, Data)
    func sendMessage(to: Address, data: Data) throws -> Void
}

protocol SocketCommon {
    func close() throws
}

protocol ReadableSocket: ConnectableSocket, BindableSocket {

}

protocol WriteableSocket: ConnectableSocket, BindableSocket {

    /// Send the provided data
    /// - Throws Underlying ZMQ error when data could not be sent
    func send(_ data: Data, options: SocketSendRecvOption) throws -> Void
}

protocol SubscriberSocket: ReadableSocket {
    func subscribe(to: String) throws
}

extension Socket: ReadableSocket {}
extension Socket: WriteableSocket {}

class ZeroMQ {
    private var context: UnsafeMutableRawPointer?

    // MARK: - Req/rep
    func requestSocket()  throws -> ReadableSocket & WriteableSocket {
        return try Socket(context: context, type: .request)
    }

    func replySocket()  throws -> ReadableSocket & WriteableSocket {
        return try Socket(context: context, type: .reply)
    }

    // MARK: - Pub/sub
    func publisherSocket()  throws -> WriteableSocket {
        return try Socket(context: context, type: .publish)
    }

    func subscriberSocket()  throws -> SubscriberSocket {
        return try Socket(context: context, type: .subscribe)
    }

    // MARK: - Push/pull
    func pushSocket()  throws -> WriteableSocket {
        return try Socket(context: context, type: .push)
    }

    func pullSocket()  throws -> ReadableSocket {
        return try Socket(context: context, type: .pull)
    }

    // MARK: - Dealer/router
    func dealerSocket() throws -> WriteableSocket {
        return try Socket(context: context, type: .dealer)
    }

    func routerSocket() throws -> AddressableSocket  {
        return try Socket(context: context, type: .router)
    }
}
