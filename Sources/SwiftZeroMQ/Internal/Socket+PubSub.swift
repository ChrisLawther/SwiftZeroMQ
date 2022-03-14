import Foundation
import CZeroMQ

extension Socket: PublisherSocket { }

extension Socket: SubscriberSocket {
    public func subscribe(to topic: Data) throws {
        guard let socket = socket else {
            fatalError("Tried to connect from a non-existant socket")
        }

        let result = topic.withUnsafeBytes { unsafeRawBufferPointer in
            return zmq_setsockopt(socket, ZMQ_SUBSCRIBE, unsafeRawBufferPointer.baseAddress, topic.count)
        }

        if result == -1 {
            throw ZMQError.lastError()
        }
    }
}
