import Foundation
import CZeroMQ

public protocol ConnectableSocket {
    func connect(to: Endpoint) throws
}

public protocol BindableSocket {
    func bind(to: Endpoint) throws
}

/// Describes the sender or recipient of a message in a dealer/router scenario
public struct Address {
    let sender: Data
}

public protocol AddressableSocket {

    /// Receive a message from an addressable source
    /// - Returns: The sender address (as an opaque type) and the received data
    func receiveMessage() throws -> (Address, Data)

    /// Send a message back to an addressable receiver
    /// - Parameters:
    ///   - to: The address to send to
    ///   - data: The message body
    /// - Throws: If the message could not be sent
    func sendMessage(to: Address, data: Data) throws -> Void
}

public typealias RequestSocket = ReadableSocket & WriteableSocket
public typealias ReplySocket = ReadableSocket & WriteableSocket
public typealias DealerSocket = ReadableSocket & WriteableSocket
public typealias RouterSocket = ReadableSocket & AddressableSocket
