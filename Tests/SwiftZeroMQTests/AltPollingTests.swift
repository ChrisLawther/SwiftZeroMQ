import XCTest
@testable import SwiftZeroMQ

final class AltPollerTests: XCTestCase {

    func testASocketReceivingDataBecomesReadable() throws {
        try withPushPullPair { pusher, puller in
            let sut = Wibble()

            var expectedMessageCount = 3

            let becameReadable = expectation(description: "Socket should have become readable")

            for idx in 0..<expectedMessageCount {
                _ = pusher.send("Hello \(idx)", options: .dontWait)
            }

            sut.poll(socket: puller, flags: .pollIn) { socket in
                let messages: [String]? = try? socket.receiveMessage().get()
                for msg in messages ?? [] {
                    print("🔖 \(msg)")
                    expectedMessageCount -= 1
                    if expectedMessageCount == 0 {
                        becameReadable.fulfill()
                    }
                }
                XCTAssert(socket === puller)
            }

            wait(for: [becameReadable], timeout: 5)
        }
    }
}

