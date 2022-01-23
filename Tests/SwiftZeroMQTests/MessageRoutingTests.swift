import XCTest
@testable import SwiftZeroMQ

class ImmediateRunner: Worker {
    private (set) var afterBlock: (() -> Void)?

    //
    var count = 2

    func async(_ block: @escaping () -> Void) {
        guard count > 0 else {
            return print("Used-up, NOT fake aync()-ing")
        }
        print("fake aync()-ing")
        block()
        count -= 1
    }

    func asyncAfter(deadline: DispatchTime, _ block: @escaping () -> Void) {
        print("fake ayncAfter()-ing")
        afterBlock = block
    }

    func tick() {
        afterBlock?()
    }
}

final class MessageRoutingTests: XCTestCase {
    var ctx: ZMQ!
    var requester: RequestSocket!
    var replier: ReplySocket!
    var runner = ImmediateRunner()
    var poller: SocketPoller!
    var router: MessageRouter!

    override func setUpWithError() throws {
        runner = ImmediateRunner()
        poller = SocketPoller(worker: runner)
        router = MessageRouter(poller: poller)
        ctx = try ZMQ(poller: poller, router: router)
        requester = try ctx.requestSocket()
        replier = try ctx.replySocket()

        try requester.connect(to: .inproc(name: "reqrep"))
        try replier.bind(to: .inproc(name: "reqrep"))
    }

    func testHandlerIsCalledWhenMessageMatchingIdentifierIsReceived() throws {
        let messageWasRouted = expectation(description: "Message should have been routed")

        try requester.send(["GREETING", "Hello!"])

        try replier.on("GREETING") { data in
            guard let message = String(data: data.first!, encoding: .utf8) else {
                return XCTFail("Message received, but corrupted?")
            }
            XCTAssertEqual(message, "Hello!")
            messageWasRouted.fulfill()
        }

        poller.poll()

        wait(for: [messageWasRouted], timeout: 1)
    }

    func testDecodingHandlerIsCalledWhenRecognisedTypeIsReceived() throws {
        let messageWasRouted = expectation(description: "Message should have been routed")

        try requester.send([String.identifier, "Hello!"])

        try replier.on() { (message: String) in
            XCTAssertEqual(message, "Hello!")
            messageWasRouted.fulfill()
        }

        poller.poll()

        wait(for: [messageWasRouted], timeout: 1)
    }

    func testDecodingHandlerIsNotCalledWhenIdentifiersDontMatch() throws {

        try replier.on() { (message: String) in

            // This is falsely passing because we don't hang around
            // long enough for poll/read/decode to happen
            XCTFail("Should not have been called")
        }

        try requester.send(["WRONG_ID", "Hello!"])

        poller.poll()

    }

    func testWhenMultipleHandlerAreRegistered_CorrectHandlerIsCalled() throws {
        let messageWasRoutedToCorrectHandler = expectation(description: "Message was correctly routed")

        try requester.send(["Correct", "Hello!"])

        try replier.on("Correct") { data in
            messageWasRoutedToCorrectHandler.fulfill()
        }

        try replier.on("Other") { data in
            XCTFail("Message was routed to incorrect handler")
        }

        poller.poll()

        wait(for: [messageWasRoutedToCorrectHandler], timeout: 2)
    }
}
