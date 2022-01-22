import XCTest
import SwiftZeroMQ

class ImmediateRunner: Worker {
    func async(_ block: @escaping () -> Void) {
        DispatchQueue.global(qos: .utility).sync(execute: block)
    }

    func asyncAfter(deadline: DispatchTime, _ block: @escaping () -> Void) {
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: deadline, execute: block)
    }
}

final class MessageRoutingTests: XCTestCase {
    var ctx: ZMQ!
    var requester: RequestSocket!
    var replier: ReplySocket!

    override func setUpWithError() throws {
        ctx = try ZMQ() //worker: ImmediateRunner())
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

    func testDecodingHandlerIsCalledWhenRecognisedTypeIsReceived() throws {
        let messageWasRouted = expectation(description: "Message should have been routed")

        try replier.on() { (message: String) in
            XCTAssertEqual(message, "Hello!")
            messageWasRouted.fulfill()
        }

        try requester.send(["GREETING", "Hello!"])

        wait(for: [messageWasRouted], timeout: 1)
    }

    func testDecodingHandlerIsNotCalledWhenIdentifiersDontMatch() throws {
//        let messageWasRouted = expectation(description: "Message should have been routed")

        try replier.on() { (message: String) in

            // This is falsely passing because we don't hang around
            // long enough for poll/read/decode to happen
            XCTFail("Should not have been called")
        }

        try requester.send(["WRONG_ID", "Hello!"])

        // ... even with the sleep()
        sleep(1)
//        wait(for: [messageWasRouted], timeout: 1)
    }

    func testWhenMultipleHandlerAreRegistered_CorrectHandlerIsCalled() throws {
        
    }
}
