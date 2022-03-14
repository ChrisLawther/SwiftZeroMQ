import Foundation
import CZeroMQ

public protocol WriteableSocket: ConnectableSocket, BindableSocket {
    func send(_ data: Data, options: SocketSendRecvOption) throws -> Void
}

extension WriteableSocket {
    public func send(_ data: [Data]) throws -> Void {
        for packet in data[0..<(data.count-1)] {
            try send(packet, options: .dontWaitSendMore)
        }
        if let final = data.last {
            try send(final, options: .dontWait)
        }
    }

    /// Send the provided data
    /// - Throws Underlying ZMQ error when data could not be sent
    public func send(_ message: String, options: SocketSendRecvOption = .none) throws -> Void {
        guard let data = message.data(using: .utf8) else {
            throw ZMQError.stringCouldNotBeEncoded(message)
        }
        try send(data, options: options)
    }

    public func send(_ fragments: [String]) throws -> Void {
        let packets = try fragments.map { fragment -> Data in
            guard let data = fragment.data(using: .utf8) else {
                throw ZMQError.stringCouldNotBeEncoded(fragment)
            }
            return data
        }
        try send(packets)
    }
}
