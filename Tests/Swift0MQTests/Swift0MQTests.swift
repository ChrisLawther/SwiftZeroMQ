import XCTest
@testable import Swift0MQ

final class Swift0MQTests: XCTestCase {
    func testCanReportCurrentVersion() {
        let (major, minor, patch, versionString) = zmqVersion()

        XCTAssertEqual(major, 4)
        XCTAssertEqual(minor, 3)
        XCTAssertEqual(patch, 2)
        XCTAssertEqual(versionString, "4.3.2")
    }

    func testCanCreateContext() throws {
        let zmq: ZMQ? = try ZMQ()
        XCTAssertNotNil(zmq)
    }

    func testCanCreateMultipleContexts() throws {
        let zmq1: ZMQ? = try ZMQ()
        let zmq2: ZMQ? = try ZMQ()
        XCTAssertNotNil(zmq1)
        XCTAssertNotNil(zmq2)
    }

    func testRequestSocketCanSendToReplySocket() throws {
        try withRequestReplyPair { requester, replier in
            _ = requester.send(data: "Hello".data(using: .utf8)!, options: .none)

            let buffer = try replier.receive(size: 10).get()
            let msg = String(data: buffer, encoding: .utf8) ?? "😫"
            XCTAssertEqual(msg, "Hello")
        }
    }

    // It's not so much "cannot" as "blocks until"
    func xtestRequestSocketCannotSendToReplySocketWithPendingResponse() throws {
        try withRequestReplyPair { requester, replier in
            _ = requester.send(data: "Hello".data(using: .utf8)!, options: .none)

            XCTAssertThrowsError({
                try requester.send(data: "Hello".data(using: .utf8)!, options: .none).get()
            })
        }
    }

    func xtestReplyingBeforeThereWasARequestFails() throws {
        try withRequestReplyPair { requester, replier in
            XCTAssertThrowsError({
                try replier.send(data: "Hi there!".data(using: .utf8)!, options: .none).get()
                try replier.send(data: "Hi there!".data(using: .utf8)!, options: .none).get()
            })
        }
    }

    func testReplySocketCanRespondToRequestSocket() throws {
        try withRequestReplyPair { requester, replier in
            _ = requester.send(data: "Hello".data(using: .utf8)!, options: .none)
            _ = try replier.receive(size: 10).get()   // The message needs to be read before the response can be sent
            _ = replier.send(data: "Hi there!".data(using: .utf8)!, options: .none)

            let buffer = try requester.receive(size: 10).get()
            let msg = String(data: buffer, encoding: .utf8) ?? "😫"
            XCTAssertEqual(msg, "Hi there!")
        }
    }

    func testSubscriberCanSubscribeToAllTopicsOnPublisher() throws {
        try withPubSubPair { publisher, subscriber in
            try subscriber.subscribe()

            publisher.send(data: "message".data(using: .utf8)!, options: .none)

            let buffer = try subscriber.receive(size: 10, options: .dontWait).get()
            let msg = String(bytes: buffer, encoding: .utf8) ?? "😫"

            XCTAssertEqual(msg, "message")
        }
    }

    // ZeroMQ "topic"s are just the suffix (any length) of the message
    func testSubscriberCanSubscribeToSpecificTopicOnPublisher() throws {
        try withPubSubPair { publisher, subscriber in
            try subscriber.subscribe(to: "niche.")

            publisher.send(data: "message".data(using: .utf8)!, options: .none)
            publisher.send(data: "niche.message".data(using: .utf8)!, options: .none)

            let buffer = try subscriber.receive(size: 20, options: .dontWait).get()
            let msg = String(bytes: buffer, encoding: .utf8) ?? "😫"

            XCTAssertEqual(msg, "niche.message")

        }
    }
//
//    func testPublisherCanBroadcastToAllSubscribers() throws {
//        XCTFail("Not implemented")
//    }
//
//    func testPublisherCanBroadcastToSubscribersToTopics() throws {
//        XCTFail("Not implemented")
//    }
//
    func testPusherCanSendToPuller() throws {
        try withPushPullPair { pusher, puller in
            for _ in 1...10 {
                _ = pusher.send(data: "Hello".data(using: .utf8)!, options: .dontWait)
                _ = try puller.receive(size: 10).get()
            }
        }
    }

//    static var allTests = [
//        ("testCanCreateContext", testCanCreateContext),
//    ]
}

private extension Swift0MQTests {

    func withPubSubPair(_ block: (Socket, Socket) throws -> Void) throws {
        let (ctx, subscriber, publisher) = try contextAndPairWithTypes(first: .subscribe, second: .publish)
        try block(publisher, subscriber)
        try ctx.shutdown()
    }

    func withRequestReplyPair(_ block: (Socket, Socket) throws -> Void) throws {
        let (ctx, first, second) = try contextAndPairWithTypes(first: .request, second: .reply)

        try block(first, second)

        try ctx.shutdown()
    }

    func withPushPullPair(_ block: (Socket, Socket) throws -> Void) throws {
        let (ctx, first, second) = try contextAndPairWithTypes(first: .push, second: .pull)

        try block(first, second)

        try ctx.shutdown()
    }

    private func contextAndPairWithTypes(first: SocketType, second: SocketType) throws -> (ZMQ, Socket, Socket) {
        let zmq = try ZMQ()

        let socketA = try zmq.socket(type: first)
        _ = try socketA.connect(to: "inproc://testing")

        let socketB = try zmq.socket(type: second)
        _ = try socketB.bind(to: "inproc://testing")

        return (zmq, socketA, socketB)
    }
}
