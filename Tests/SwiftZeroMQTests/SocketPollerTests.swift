import XCTest
import SwiftZeroMQ

final class SocketPollerTests: XCTestCase {
    var ctx: ZMQ!
    var requester: RequestSocket!
    var replier: ReplySocket!

    override func setUpWithError() throws {
        ctx = try ZMQ()
        requester = try ctx.requestSocket()
        replier = try ctx.replySocket()

        try requester.connect(to: .inproc(name: "reqrep"))
        try replier.bind(to: .inproc(name: "reqrep"))
    }

    func testHandlerIsCalledWhenSocketBecomesReadable() throws {
        let becameReadable = expectation(description: "Socket should have become readable")

        replier.on(flags: .pollIn) { socket in
            _ = try? socket.receiveMultipartMessage()
            becameReadable.fulfill()
        }

        try requester.send("Hello")

        wait(for: [becameReadable], timeout: 1)
    }

}
