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
        let (ctx, requester, replier) = try contextWithRequestReplyPair()

        _ = requester.send(data: "Hello".data(using: .utf8)!, options: .none)

        let buffer = try replier.receive(size: 10).get()
        let msg = String(data: buffer, encoding: .utf8) ?? "😫"
        XCTAssertEqual(msg, "Hello")
    }

    // It's not so much "cannot" as "blocks until"
    func xtestRequestSocketCannotSendToReplySocketWithPendingResponse() throws {
        let (ctx, requester, replier) = try contextWithRequestReplyPair()

        _ = requester.send(data: "Hello".data(using: .utf8)!, options: .none)

        XCTAssertThrowsError({
            try requester.send(data: "Hello".data(using: .utf8)!, options: .none).get()
        })
    }

    func xtestReplyingBeforeThereWasARequestFails() throws {
        let (ctx, requester, replier) = try contextWithRequestReplyPair()

        XCTAssertThrowsError({
            try replier.send(data: "Hi there!".data(using: .utf8)!, options: .none).get()
            try replier.send(data: "Hi there!".data(using: .utf8)!, options: .none).get()
        })
    }

    func testReplySocketCanRespondToRequestSocket() throws {
        let (ctx, requester, responder) = try contextWithRequestReplyPair()

        _ = requester.send(data: "Hello".data(using: .utf8)!, options: .none)
        _ = try responder.receive(size: 10).get()   // The message needs to be read before the response can be sent
        _ = responder.send(data: "Hi there!".data(using: .utf8)!, options: .none)

        let buffer = try requester.receive(size: 10).get()
        let msg = String(data: buffer, encoding: .utf8) ?? "😫"
        XCTAssertEqual(msg, "Hi there!")
    }
//
//    func testSubscriberCanSubscribeToPublisher() {
//        XCTFail("Not implemented")
//    }
//
//    func testPublisherCanBroadcastToAllSubscribers() {
//        XCTFail("Not implemented")
//    }
//
//    func testPublisherCanBroadcastToSubscribersToTopics() {
//        XCTFail("Not implemented")
//    }
//
    func testPusherCanSendToPuller() throws {
        let (ctx, pusher, puller) = try contextWithPushPull()

        for _ in 1...10 {
            _ = pusher.send(data: "Hello".data(using: .utf8)!, options: .dontWait)
            _ = try puller.receive(size: 10).get()
        }

        try ctx.shutdown()
    }

    // W-a-y faster
    func testInProcPusherCanSendToPuller() throws {
        let (ctx, pusher, puller) = try contextWithInProcPushPull()

        for _ in 1...10000 {
            _ = pusher.send(data: "Hello".data(using: .utf8)!, options: .dontWait)
            _ = try puller.receive(size: 10).get()
        }

        try ctx.shutdown()
    }

//    static var allTests = [
//        ("testCanCreateContext", testCanCreateContext),
//    ]
}

private extension Swift0MQTests {
    func contextWithRequestReplyPair() throws -> (ZMQ, Socket, Socket) {
        return try contextAndPairWithTypes(first: .request, second: .reply)
    }

    func contextWithPushPull() throws -> (ZMQ, Socket, Socket) {
        return try contextAndPairWithTypes(first: .push, second: .pull)
    }

    func contextWithInProcPushPull() throws -> (ZMQ, Socket, Socket) {
        let zmq = try ZMQ()

        let socketA = try zmq.socket(type: .push)
        _ = try socketA.connect(to: "inproc://testing")

        let socketB = try zmq.socket(type: .pull)
        _ = try socketB.bind(to: "inproc://testing")

        return (zmq, socketA, socketB)
    }

    private func contextAndPairWithTypes(first: SocketType, second: SocketType) throws -> (ZMQ, Socket, Socket) {
        let zmq = try ZMQ()

        let socketA = try zmq.socket(type: first)
        _ = try socketA.connect(to: "tcp://localhost:6666")

        let socketB = try zmq.socket(type: second)
        _ = try socketB.bind(to: "tcp://*:6666")

        return (zmq, socketA, socketB)
    }
}
