import XCTest
import SwiftZeroMQ

final class MessageRoutingTests: XCTestCase {
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

    func testHandlerIsCalledWhenMessageMatchingIdentifierIsReceived() throws {
        let messageWasRouted = expectation(description: "Message should have been routed")

        try replier.on("GREETING") { data in
            guard let message = String(data: data.first!, encoding: .utf8) else {
                return XCTFail("Message received, but corrupted?")
            }
            XCTAssertEqual(message, "Hello!")
            messageWasRouted.fulfill()
        }

        try requester.send(["GREETING", "Hello!"])

        wait(for: [messageWasRouted], timeout: 1)
    }

    func testWhenMultipleHandlerAreRegistered_CorrectHandlerIsCalled() throws {
        
    }
}
