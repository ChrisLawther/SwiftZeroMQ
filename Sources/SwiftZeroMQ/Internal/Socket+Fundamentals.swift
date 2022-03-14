import Foundation
import CZeroMQ

// MARK: - BindableSocket

extension Socket: BindableSocket {
    public func bind(to endpoint: Endpoint) throws {
        guard let socket = socket else {
            fatalError("Tried to bind a non-existant socket")
        }
        let result = zmq_bind(socket, endpoint.path)

        if result == -1 {
            throw ZMQError.lastError()
        }
    }
}

// MARK: - ConnectableSocket

extension Socket: ConnectableSocket {
    public func connect(to endpoint: Endpoint) throws {
        guard let socket = socket else {
            fatalError("Tried to connect from a non-existant socket")
        }
        let result = zmq_connect(socket, endpoint.path)

        if result == -1 {
            throw ZMQError.lastError()
        }
    }
}


extension Socket: AddressableSocket {
    public func receiveMessage() throws -> (Address, Data) {
        let data: [Data] = try receiveMultipartMessage()
        return (Address(sender: data[0]), data[1])
    }

    public func sendMessage(to address: Address, data: Data) throws {
        try send([address.sender, data])
    }
}
