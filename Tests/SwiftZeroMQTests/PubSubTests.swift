import XCTest
import SwiftZeroMQ

final class PubSubTests: XCTestCase {
    var ctx: ZMQ!
    var publisher: WriteableSocket!
    var subscriber: SubscriberSocket!

    override func setUpWithError() throws {
        ctx = try ZMQ.standard()
        publisher = try ctx.publisherSocket()
        subscriber = try ctx.subscriberSocket()

        try subscriber.connect(to: .inproc(name: "pubsub"))
        try publisher.bind(to: .inproc(name: "pubsub"))
    }

    func testSubscriberCanSubscribeToAllTopicsOnPublisher() throws {
        try subscriber.subscribe()

        try publisher.send("message", options: .none)

        let received = try subscriber.receiveStringMessage()

        XCTAssertEqual(received, "message")
    }

    func testSubscriberSubscribedToSpecificTopicOnlyReceivesMessagesOnThatTopic() throws {

        try subscriber.subscribe(to: "foo")

        try publisher.send("foo.message", options: .none)
        try publisher.send("bar.message", options: .none)

        let received = try subscriber.receiveStringMessage()

        XCTAssertEqual(received, "foo.message")
    }

    func testMultipleSubsribersToOnePublisherReceiveOnlyMessagesTheyHaveSubscribedTo() throws {
        let subscriber2 = try ctx.subscriberSocket()
        try subscriber2.connect(to: .inproc(name: "pubsub"))

        try subscriber.subscribe(to: "foo")
        try subscriber2.subscribe(to: "bar")

        try publisher.send("foo.message", options: .none)
        try publisher.send("bar.message", options: .none)

        do {
            let msg1 = try subscriber.receiveStringMessage()
            let msg2 = try subscriber2.receiveStringMessage()

            XCTAssertEqual(msg1, "foo.message")
            XCTAssertEqual(msg2, "bar.message")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
}
