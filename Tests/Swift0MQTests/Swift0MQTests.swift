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
        let zmq = try ZMQ()

        let requester = try zmq.socket(type: .request)
        _ = try requester.connect(to: "tcp://localhost:5555")

        let responder = try zmq.socket(type: .reply)
        _ = try responder.bind(to: "tcp://*:5555")

        _ = requester.send(data: "Hello".data(using: .utf8)!, options: .none)

        _ = responder.receive(size: 10).map { buffer -> Void in
            let msg = String(data: buffer, encoding: .utf8) ?? "😫"
            XCTAssertEqual(msg, "Hello")
        }
    }

//    func testReplySocketCanSendToRequestSocket() throws {
//        XCTFail("Not implemented")
//    }
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
//    func testPusherCanSendToPuller() {
//        XCTFail("Not implemented")
//    }

//    static var allTests = [
//        ("testCanCreateContext", testCanCreateContext),
//    ]
}
