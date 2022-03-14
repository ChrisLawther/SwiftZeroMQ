import Foundation
import CZeroMQ

struct ZmqError: Error, LocalizedError {
    let errNo: Int32
    var errorDescription: String { String(cString: zmq_strerror(errNo)) }
}

// MARK: - Socket

public class Socket {
    var socket: UnsafeMutableRawPointer?
    let context: ZMQ

    /// Attempts to create a new socket of the specified type
    /// - Parameters:
    ///   - zmq: The parent context
    ///   - socket: The underlying zmq socket
    init(zmq: ZMQ, socket: UnsafeMutableRawPointer) {
        self.context = zmq
        self.socket = socket
    }

    deinit {
        do {
            try close()
        } catch {
            print(error)
        }
    }

    /// Closes the socket
    /// - Throws: If the socket was already NULL (can't happen?)
    func close() throws {
        guard let socket = socket else { return }

        let result = zmq_close(socket)

        if result == -1 {
            throw ZMQError.lastError()
        } else {
            // Success
            self.socket = nil
        }
    }
}

extension Socket: Hashable {
    public static func == (lhs: Socket, rhs: Socket) -> Bool {
        return lhs.socket == rhs.socket
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self).hashValue)
    }
}
