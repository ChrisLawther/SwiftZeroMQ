import Foundation
import XCTest
import SwiftZeroMQ

final class IdentifiableMessageTests: XCTestCase {

    func testRoundTrip() throws {
        let original = StringMessage("Hello world!")
        let payload = original.payload!

        let final = try StringMessage(payload)

        XCTAssertEqual(original.id, "StringMessage")
        XCTAssertEqual(final.string, "Hello world!")
    }

    func testDiscardingTokenRemovesSubscription() {
        let t = Thing()

        var token: SubscriptionToken? = t.on("foo") { _ in }

        XCTAssertEqual(Array(t.handlers.keys), ["foo"])

        token = nil

        XCTAssertTrue(t.handlers.isEmpty)
    }

    func testMessageIsPassedToCorrespondingHandler() {
        let t = Thing()

        var fooDidHappen = false
        var barDidHappen = false

        let fooToken = t.on("foo") { _ in fooDidHappen = true }
        let barToken = t.on("bar") { _ in barDidHappen = true }

        t.handle(Data(), for: "foo")

        XCTAssertTrue(fooDidHappen)
        XCTAssertFalse(barDidHappen)
    }
}

class SubscriptionToken {
    private let deregister: () -> Void

    init(_ deregister: @escaping () -> Void) {
        self.deregister = deregister
    }

    deinit {
        deregister()
    }
}

class Thing {
    var handlers = [String: (Data) -> Void]()

    func on(_ identifier: String, handler: @escaping (Data) -> Void) -> SubscriptionToken {

        handlers[identifier] = handler

        let token = SubscriptionToken { [weak self] in
            self?.handlers[identifier] = nil
        }

        return token
    }

    func handle(_ data: Data, for identifier: String) {
        handlers[identifier]?(data)
    }
}
