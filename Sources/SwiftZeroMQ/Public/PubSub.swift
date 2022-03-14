import Foundation
import CZeroMQ

// MARK: - Publisher

public protocol PublisherSocket: WriteableSocket { }

extension PublisherSocket {
    func publish(topic: String, data: Data) throws -> Void {
        try send([topic.data(using: .utf8)!, data])
    }
}

// MARK: - Subscriber

public protocol SubscriberSocket: ReadableSocket {
    func subscribe(to: Data) throws
}

public extension SubscriberSocket {
    func subscribe(to topic: String) throws {
        guard let bytes = topic.data(using: .utf8) else {
            // TODO: Throw "invalidTopicError" ?
            return
        }
        try subscribe(to: bytes)
    }
}

public extension SubscriberSocket {
    func subscribe() throws {
        try subscribe(to: "")
    }
}
