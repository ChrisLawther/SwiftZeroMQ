import Foundation

@available(macOS 10.15, *)
protocol Sendable: Identifiable {
    var payload: Data? { get }
}

@available(macOS 10.15, *)
protocol Receivable: Identifiable {
    init(_ data: Data) throws
}

// A two-part message, where the first part identifies the type
// (and can be used to key into a dictionary of handlers)
// and the second-part is the payload, decodable to that type
// (by a caller-provided handler)
public struct StringMessage: Sendable, Receivable {
    public let id = String(describing: Self.self)
    public var payload: Data? { string.data(using: .utf8) }
    public let string: String

    enum Error: Swift.Error {
        case invalidUTF8Data
    }

    public init(_ string: String) {
        self.string = string
    }

    public init(_ data: Data) throws {
        guard let string = String(data: data, encoding: .utf8) else {
            throw Error.invalidUTF8Data
        }
        self.string = string
    }
}
