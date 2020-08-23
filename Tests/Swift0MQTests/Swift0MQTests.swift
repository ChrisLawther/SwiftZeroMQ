import XCTest
@testable import Swift0MQ

final class Swift0MQTests: XCTestCase {
    func testCanCreateContext() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.

        let zmq: ZMQ? = try ZMQ()
        XCTAssertNotNil(zmq)
    }

    func testCanSendRequests() throws {
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

    static var allTests = [
        ("testCanCreateContext", testCanCreateContext),
    ]
}
