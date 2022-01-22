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
        let msg = try replier.receiveStringMessage(options: .none)
        XCTAssertEqual(msg, "Hello")
    }

    func testReplierCanRespondToRequester() throws {
        try requester.send("Hello", options: .none)
        var _: Data = try replier.receiveMessage(options: .none)

        try replier.send("response", options: .none)

        let msg = try requester.receiveStringMessage(options: .none)
        XCTAssertEqual(msg, "response")
    }

    func testCanSendMultipartMessages() throws {
        try requester.send(["Hello", "There"])
        let received = try replier.receiveMultipartMessage()

        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(received.first, "Hello".data(using: .utf8))
        XCTAssertEqual(received.dropFirst().first, "There".data(using: .utf8))
    }

    func testReplierCanPollForRequests() throws {
//        let msg = IdentifiedStringMessage(["Hello"])
//        replier.on(
//        try requester.send("Hello", options: .none)
//        var _: Data = try replier.receiveMessage(options: .none)

    }

    func testRequesterCanPollForReplies() throws {

    }
}
