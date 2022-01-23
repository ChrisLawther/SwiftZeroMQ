import XCTest
import SwiftZeroMQ

final class PushPullTests: XCTestCase {
    var ctx: ZMQ!
    var pusher: WriteableSocket!
    var puller: ReadableSocket!

    override func setUpWithError() throws {
        ctx = try ZMQ.standard()
        pusher = try ctx.pushSocket()
        puller = try ctx.pullSocket()

        try pusher.connect(to: .inproc(name: "pubsub"))
        try puller.bind(to: .inproc(name: "pubsub"))
    }

    func testMessagesSentToPusher_CanBeReceivedByPusher() throws {
        try pusher.send("Hello")

        let received = try puller.receiveStringMessage()

        XCTAssertEqual(received, "Hello")
    }

    func testPullerCanPollForMessagesFromPusher() throws {
        let wasReadable = expectation(description: "Socket should have become readable")

        puller.on(flags: .pollIn) { socket in
            // Must consume the message
            _ = try? socket.receiveMultipartMessage()
            wasReadable.fulfill()
        }

        try pusher.send("Greetings!")

        wait(for: [wasReadable], timeout: 1)
    }

}
