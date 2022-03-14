import Foundation
import CZeroMQ

public protocol ReadableSocket: ConnectableSocket, BindableSocket {
    /// The lowest level of message reception
    /// - Parameters:
    ///   - options: Flags specifying whether to block/wait and whether there are more parts to follow
    /// - Returns: The received data
    /// - Throws: Underlying error, if any
    func receiveMessage(options: SocketSendRecvOption) throws -> Data

    /// Receive a multi-part message, returning an array of `Data`
    /// - Returns: Array of `Data` of the message parts
    /// - Throws: Underlying error, if any
    func receiveMultipartMessage() throws -> [Data]

    /// For a multi-part message beginning with a part matching `identifier`, passes the
    /// remaining parts to the handler
    /// - Parameters:
    ///   - identifier: The message identifier
    ///   - handler: A closure to handle an array of the remaining message parts
    func on(_ identifier: Data, handler: @escaping ([Data]) -> Void)

    /// When the socket can satisfy one or more of the given flags, pass the socket to the handler
    /// - Parameters:
    ///   - flags: Flags specifying one or more of Readable, Writable, Errored
    ///   - handler: A function accepting the Socket as a parameter
    func on(flags: PollingFlags, handler: @escaping (Socket) -> Void)
}

extension ReadableSocket {

    /// A convenience that attempts to decode the received data as a UTF-8 string
    /// - Parameter options: Flags specifying whether to block/wait and whether there are more parts to follow
    /// - Returns: The decoded string
    /// - Throws: If the underlying message reception or the utf-8 decode failed
    public func receiveStringMessage(options: SocketSendRecvOption = .none) throws -> String {
        let data = try receiveMessage(options: options)

        guard let message = String(data: data, encoding: .utf8) else {
            throw ZMQError.invalidUTF8String
        }
        return message
    }

    /// A convenience that attempts to convert the provided String identifier into the required Data, using utf-8 encoding
    /// - Parameters:
    ///   - identifier: The String form of the message identifier
    ///   - handler: Function to handle any received messages, which may be multi-part
    /// - Throws: If the provided identifier could not be encoded
    public func on(_ identifier: String, handler: @escaping ([Data]) -> Void) throws {
        guard let data = identifier.data(using: .utf8) else {
            throw ZMQError.stringCouldNotBeEncoded(identifier)
        }
        on(data, handler: handler)
    }

    /// A convenience that wraps `.on(type:handler:)` with deserialisation to the expected message type
    /// - Parameters:
    ///   - type: The message type to receive
    ///   - handler: Function (or closure) to receive successfully decoded messages
    /// - Throws: The underlying error
    public func on<T: MessageIdentifiable>(_ type: T.Type = T.self, handler: @escaping (T) -> Void) throws -> Void {
        try on(type.identifier) { data in
            let message = T.init(data[0])
            handler(message)
        }
    }
}
