import Foundation

public protocol DataRepresentable {
    var data: Data { get }
}

public protocol DataInitialisable {
    init(_ data: Data)
}

extension String: DataRepresentable {
    public var data: Data { data(using: .utf8) ?? Data() }
}

extension String: DataInitialisable {
    public init(_ data: Data) {
        self.init(data: data, encoding: .utf8)!
    }
}

public protocol IdentifiableMessage {
    associatedtype Payload where Payload: DataRepresentable & DataInitialisable
    static var identifier: String { get }
    var parts: [Payload] { get }
}

extension IdentifiableMessage {
    public static var identifier: String { String(describing: Self.self) }
}

public struct IdentifiedStringMessage: IdentifiableMessage {
    public typealias Payload = String
    public let parts: [String]

    public init(_ parts: [String]) {
        self.parts = parts
    }
}

public protocol MessageIdentifiable: DataInitialisable {
    static var identifier: String { get }
}

public extension MessageIdentifiable {
    static var identifier: String { String(describing: self) }
}

extension String: MessageIdentifiable {}
