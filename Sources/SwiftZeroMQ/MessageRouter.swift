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
        let receiver = ReceiverIdentifier(identifier: identifier, socket: socket)
        handlers[receiver] = handler

        guard handler != nil else {
            // TODO: - Stop polling a socket once all message handlers for that socket
            //         have been removed
            print("🧐 Message router DE-registering")
            return
        }

        print("🧐 Message router registering socket for polling")
        poller.poll(socket: socket, flags: .pollIn) { [weak self] socket in
            try? self?.handleReadable(socket: socket)
        }
    }

    private func handleReadable(socket: Socket) throws {
        print("🧐 Message router reading socket")
        let multipart = try socket.receiveMultipartMessage()

        guard !multipart.isEmpty else {
            print("Ignoring empty message")
            return
        }
        let identifier = multipart[0]
        let handlerKey = ReceiverIdentifier(identifier: identifier, socket: socket)
        do {
            guard let handler = handlers[handlerKey] else {
                return
            }
            try handler(Array(multipart.dropFirst()))
            print("🧐 Message router called handler successfully")
        } catch {
            let idStr = String(data: identifier, encoding: .utf8) ?? identifier.prefix(8).map {
                String(format: "%02hhx", $0)
            }.joined() + "..."

            os_log("Failed to route message id '%{public}@': %{public}@", log: .messageRouting, type: .info, idStr, error.localizedDescription)
        }
    }
}
