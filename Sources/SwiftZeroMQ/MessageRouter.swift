import Foundation
import os.log

extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier!

    static let messageRouting = OSLog(subsystem: subsystem, category: "messageRouting")
}

public typealias MessageHandler = ([Data]) throws -> Void

class MessageRouter {
    let poller: SocketPoller

    init(poller: SocketPoller) {
        self.poller = poller
    }

    struct ReceiverIdentifier: Hashable {
        let identifier: Data
        let socket: Socket
    }

    var handlers = [ReceiverIdentifier: MessageHandler]()

    func on(identifier: String, from socket: Socket, handler: MessageHandler?) throws {
        guard let identifier = identifier.data(using: .utf8) else {
            throw ZMQError.stringCouldNotBeEncoded(identifier)
        }

        on(identifier: identifier, from: socket, handler: handler)
    }

    func on(identifier: Data, from socket: Socket, handler: MessageHandler?) {
        poller.poll(socket: socket, flags: .pollIn) { socket in
            do {
                // Right now this cares-not what the identifier was.
                // If the socket was readable, the handler from the most
                // recent call to .on() gets called
                let multipart = try socket.receiveMultipartMessage()
                try handler?(Array(multipart.dropFirst()))
            } catch {
                let idStr = String(data: identifier, encoding: .utf8) ?? identifier.prefix(8).map {
                    String(format: "%02hhx", $0)
                }.joined() + "..."

                os_log("Failed to route message id '%{public}@': %{public}@", log: .messageRouting, type: .info, idStr, error.localizedDescription)
            }
        }
    }
}
