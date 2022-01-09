import XCTest
@testable import SwiftZeroMQ

final class Swift0MQTests: XCTestCase {
    func testCanReportCurrentVersion() {
        let (major, minor, patch, versionString) = zmqVersion()

        XCTAssertEqual(major, 4)
        XCTAssertEqual(minor, 3)
        XCTAssertEqual(patch, 4)
        XCTAssertEqual(versionString, "4.3.4")
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
            _ = requester.send("Hello", options: .none)

            let msg: String = try replier.receive(size: 10).get()
            XCTAssertEqual(msg, "Hello")
        }
    }

    // It's not so much "cannot" as "blocks until"
    func xtestRequestSocketCannotSendToReplySocketWithPendingResponse() throws {
        try withRequestReplyPair { requester, replier in
            _ = requester.send("Hello", options: .none)

            XCTAssertThrowsError({
                try requester.send("Hello", options: .none).get()
            })
        }
    }

    func xtestReplyingBeforeThereWasARequestFails() throws {
        try withRequestReplyPair { requester, replier in
            XCTAssertThrowsError({
                try replier.send("Hi there!", options: .none).get()
                try replier.send("Hi there!", options: .none).get()
            })
        }
    }

    func testReplySocketCanRespondToRequestSocket() throws {
        try withRequestReplyPair { requester, replier in
            _ = requester.send("Hello", options: .none)
            let response: Data = try replier.receive(size: 10).get()   // The message needs to be read before the response can be sent
            _ = replier.send("Hi there!", options: .none)

            let msg: String = try requester.receive(size: 10).get()
            XCTAssertEqual(msg, "Hi there!")
        }
    }

    func testSubscriberCanSubscribeToAllTopicsOnPublisher() throws {
        try withPubSubPair { publisher, subscriber in
            try subscriber.subscribe()

            publisher.send("message", options: .none)

            let msg: String = try subscriber.receive(size: 10, options: .dontWait).get()

            XCTAssertEqual(msg, "message")
        }
    }

    // ZeroMQ "topic"s are just the suffix (any length) of the message
    func testSubscriberCanSubscribeToSpecificTopicOnPublisher() throws {
        try withPubSubPair { publisher, subscriber in
            try subscriber.subscribe(to: "niche.")

            publisher.send("message".data(using: .utf8)!, options: .none)
            publisher.send("niche.message", options: .none)

            let msg: String = try subscriber.receive(size: 20, options: .dontWait).get()

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
                _ = pusher.send("Hello".data(using: .utf8)!, options: .dontWait)
                let response: Data = try puller.receive(size: 10).get()
            }
        }
    }


    func testDealerCanSendToRouter() throws {
        try with(.dealer, and: .router) { dealer, router in
            for _ in 1...10 {
                _ = dealer.send("Hello", options: .dontWait)
                let client: Data = try router.receive(size: 10).get()
                let str: String = try router.receive(size: 10).get()
                print("Router received: '\(str)' from '\(client.hexEncodedString())'")
            }
        }
    }

    func testRouterCanReplyToDealer() throws {
        // NOTES: Router needs to see one message from dealer in order to know his address
        //        (which comes in as an additional first frame)
        //        Router can then respond to that dealer by sending out a multi-part message
        //        where the first part is the router's "address"
        try with(.dealer, and: .router) { dealer, router in
            for _ in 1...10 {
                _ = dealer.send("Hello", options: .dontWait)
                let client: Data = try router.receive(size: 10).get()
                let data: Data = try router.receive(size: 10).get()

                router.send(client, options: .sendMore)
                router.send(Data(data.reversed()), options: .dontWait)

                let reply = try dealer.receive().get()
                XCTAssertEqual(reply.count, 1)
                let replyStr = String(data: reply[0], encoding: .utf8)
                print("Reply: '\(replyStr ?? "<no reply>")'")
            }
        }
    }

    func testMultipartMessageIsReceived() throws {
        try withPushPullPair { pusher, puller in
            _ = pusher.send("Hello", options: .sendMore)
            _ = pusher.send("World")

            let received = try puller.receive().get()

            XCTAssertEqual(received.count, 2)
            let first = String(data: received[0], encoding: .utf8)
            let second = String(data: received[1], encoding: .utf8)

            XCTAssertEqual(first, "Hello")
            XCTAssertEqual(second, "World")
        }
    }


//    static var allTests = [
//        ("testCanCreateContext", testCanCreateContext),
//    ]
}
extension Data {
    func hexEncodedString() -> String {
        return self.map { String(format: "%02x", $0) }
            .joined()
    }
}
