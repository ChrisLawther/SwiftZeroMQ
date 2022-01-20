import XCTest
import SwiftZeroMQ

final class ReqRepTests: XCTestCase {
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

    func testRequesterCanSendToReplier() throws {
        try requester.send("Hello", options: .none)
        let msg: String = try replier.receiveMessage(options: .none)
        XCTAssertEqual(msg, "Hello")
    }

    func testReplierCanRespondToRequester() throws {
        try requester.send("Hello", options: .none)
        var _: Data = try replier.receiveMessage(options: .none)

        try replier.send("response", options: .none)

        let msg: String = try requester.receiveMessage(options: .none)
        XCTAssertEqual(msg, "response")
    }
}
