import Foundation
import CZeroMQ


// Q. Should polling for activity and routing of messages to recipients
//    be handled by a single class, or two layers?

class Wibble {
    private let worker: Worker
    private var pollMore = true
    private var keepAlive: Wibble?

    typealias EventHandler = (Socket) -> Void

    init(worker: Worker = DispatchQueue.global(qos: .utility)) {
        self.worker = worker

        keepAlive = self
        worker.async {
            self.poll2()
        }
    }

    func shutdown() {
        worker.async {
            self.pollMore = false
        }
    }

    private var toPoll = [UnsafeMutableRawPointer: (socket: Socket, flags: PollingFlags, handler: EventHandler)]()

    func poll(socket: Socket, flags: PollingFlags, handler: @escaping EventHandler) {
        guard let zmqSocket = socket.socket else {
            // Don't attempt to poll a socket that's closed (?)
            print("🧐 Can't poll a socket that's not open")
            return
        }
        worker.async {
            print("🧐 Will poll")
            self.toPoll[zmqSocket] = (socket, flags, handler)
        }
    }

    // alloc()-based approach
    private func poll() {
        let pollItems = UnsafeMutablePointer<zmq_pollitem_t>.allocate(capacity: toPoll.count)

        for (idx, (zmq, tuple)) in toPoll.enumerated() {
            pollItems[idx].socket = zmq
            pollItems[idx].events = Int16(tuple.flags.rawValue)
        }

        guard zmq_poll(pollItems, Int32(toPoll.count), 1) != -1 else {
            // Halt polling
            return shutdown()
        }

        // Notify,... something


        // Continue polling?

        if pollMore {
            worker.async {
                self.poll()
            }
        } else {
            keepAlive = nil
        }
    }

    private func poll2() {
        defer { pollAgainIfNotStopped() }
        // ... or just map and address-of?
        guard !toPoll.isEmpty else {
            print("🧐 Nothing to poll. Sleeping")

            usleep(100000)
            return
        }
        var pollItems = toPoll.map {
            zmq_pollitem_t(socket: $0.key,
                           fd: 0,
                           events: $0.value.flags.rawValue,
                           revents: 0)
        }

        print("🧐 Polling \(toPoll.count)")

        let pollResult = pollItems.withUnsafeMutableBufferPointer { ptr in
            zmq_poll(ptr.baseAddress, Int32(toPoll.count), 1)
        }
        guard pollResult != -1 else {
            // Halt polling
            print(ZMQError.lastError())
            return shutdown()
        }

        // Notify,... something
        for item in pollItems {
            print("🧐 \(item.revents)")
            if (item.revents & Int16(ZMQ_POLLIN)) != 0 {
                // Readable
                print("🧐 Socket is readable...")
                if let readable = toPoll[item.socket] {
                    print("🧐 ... and has handler")
                    readable.handler(readable.socket)
                }
            }
            if (item.revents & Int16(ZMQ_POLLOUT)) != 0 {
                // Writable
                print("🧐 Socket is writable...")
                if let writable = toPoll[item.socket] {
                    print("🧐 ... and has handler")
                    writable.handler(writable.socket)
                }
            }
            if (item.revents & Int16(ZMQ_POLLERR)) != 0 {
                // Errored
                if let errored = toPoll[item.socket] {
                    errored.handler(errored.socket)
                }
            }
        }

    }

    private func pollAgainIfNotStopped() {
        // Continue polling?
        if pollMore {
            worker.async {
                self.poll2()
            }
        } else {
            keepAlive = nil
        }
    }
}
