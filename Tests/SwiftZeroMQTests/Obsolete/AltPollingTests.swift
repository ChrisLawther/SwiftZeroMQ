//import XCTest
//@testable import SwiftZeroMQ
//
//final class AltPollerTests: XCTestCase {
//
//    func testASocketReceivingDataBecomesReadable() throws {
//        try withPushPullPair { pusher, puller in
//            var sut: Wibble? = Wibble()
//
//            var expectedMessageCount = 3
//
//            let becameReadable = expectation(description: "Socket should have become readable")
//
//            for idx in 0..<expectedMessageCount {
//                _ = pusher.send("Hello \(idx)", options: .dontWait)
//            }
//
//            // Q. Given we've pushed N messages in, why do we only
//            //    seem able to read them out 1 at a time?
//
//            sut?.poll(socket: puller, flags: .pollIn) { socket in
//                let messages: [String]? = try? socket.receiveMessage().get()
//                for msg in messages ?? [] {
//                    print("🔖 \(msg)")
//                    expectedMessageCount -= 1
//                    if expectedMessageCount == 0 {
//                        becameReadable.fulfill()
//                    }
//                }
//                XCTAssert(socket === puller)
//            }
//
//            wait(for: [becameReadable], timeout: 5)
//
//            // TODO: Make shutdown block?
//            sut?.shutdown()
//
//            weak var ref = sut
//            sut = nil
//
//            sleep(2)
//
//            XCTAssertNil(ref)
//        }
//    }
//}
//
