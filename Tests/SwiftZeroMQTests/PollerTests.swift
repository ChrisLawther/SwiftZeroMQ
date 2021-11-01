import XCTest
@testable import SwiftZeroMQ

final class PollerTests: XCTestCase {

    func testAWritableSocketIsWritable() throws {
        try withPushPullPair { pusher, puller in
            let poller = Poller()
            try poller.register(socket: pusher, flags: .pollOut)

            let sockets = try poller.poll(timeout: .immediate).get()

            XCTAssertEqual(sockets.writable.count, 1)
            XCTAssertEqual(sockets.readable.count, 0)
            XCTAssertEqual(sockets.errored.count, 0)
        }
    }

    func testASocketReceivingDataBecomesReadable() throws {
        try withPushPullPair { pusher, puller in
            let poller = Poller()
            try poller.register(socket: puller, flags: .pollIn)

            var sockets = try poller.poll(timeout: .immediate).get()

            XCTAssertEqual(sockets.readable.count, 0)

            _ = pusher.send("Hello", options: .dontWait)

            sockets = try poller.poll(timeout: .immediate).get()

            XCTAssertEqual(sockets.writable.count, 0)
            XCTAssertEqual(sockets.readable.count, 1)
            XCTAssertEqual(sockets.errored.count, 0)
        }
    }

    func testUnregisteringIsSuccessful() throws {
        try withPushPullPair { pusher, puller in
            let poller = Poller()
            try poller.register(socket: puller, flags: .pollIn)

            var sockets = try poller.poll(timeout: .immediate).get()

            XCTAssertEqual(sockets.readable.count, 0)
            poller.unregister(socket: puller)

            _ = pusher.send("Hello", options: .dontWait)

            sockets = try poller.poll(timeout: .immediate).get()

            XCTAssertEqual(sockets.writable.count, 0)
            XCTAssertEqual(sockets.readable.count, 0)
            XCTAssertEqual(sockets.errored.count, 0)
        }
    }
}

