import XCTest
import SwiftZeroMQ

final class DealerRouterTests: XCTestCase {
    var ctx: ZMQ!
    var dealer: DealerSocket!
    var router: RouterSocket!

    static let endpoint: Endpoint = .inproc(name: "dealerRouter")

    override func setUpWithError() throws {
        ctx = try ZMQ.standard()
        dealer = try ctx.dealerSocket()
        router = try ctx.routerSocket()

        try dealer.connect(to: Self.endpoint)
        try router.bind(to: Self.endpoint)
    }

    func testMessagesSentToPusher_CanBeReceivedByPusher() throws {
        try dealer.send("Hello")
        let (_, data) = try router.receiveMessage()
        let msg = String(data: data, encoding: .utf8)

        XCTAssertEqual(msg, "Hello")
    }

    func testRepliesFromRouter_ReachCorrectDealer() throws {
        let dealer2 = try ctx.dealerSocket()
        try dealer2.connect(to: Self.endpoint)

        try dealer.send("Hello_1")
        try dealer2.send("Bonjour")

        let (address1, data1) = try router.receiveMessage()
        let (address2, data2) = try router.receiveMessage()

        // Send reversed messages to *other* dealers
        try router.sendMessage(to: address2, data: Data(data1.reversed()))
        try router.sendMessage(to: address1, data: Data(data2.reversed()))

        let message1 = try dealer.receiveStringMessage()
        let message2 = try dealer2.receiveStringMessage()

        XCTAssertEqual(message1, "ruojnoB")
        XCTAssertEqual(message2, "1_olleH")
    }

}
