import Foundation
import CZeroMQ

#if !os(Linux)
import os.log

extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier!

    static let socketPolling = OSLog(subsystem: subsystem, category: "socketPolling")
}
#endif

public protocol Worker {
    func async(_ block: @escaping () -> Void)
    func asyncAfter(deadline: DispatchTime, _ block: @escaping () -> Void)
}

extension DispatchQueue: Worker {
    public func async(_ block: @escaping () -> Void) {
        async(execute: block)
    }

    public func asyncAfter(deadline: DispatchTime, _ block: @escaping () -> Void) {
        asyncAfter(deadline: deadline, execute: block)
    }
}

class SocketPoller {
    let worker: Worker
    var pollMore = true
    var keepAlive: SocketPoller?

    typealias EventHandler = (Socket) -> Void

    init(worker: Worker = DispatchQueue.global(qos: .utility)) {
        self.worker = worker

        keepAlive = self
    }

    func poll(socket: Socket, flags: PollingFlags, handler: @escaping EventHandler) {
        guard let zmqSocket = socket.socket else {
            return
        }
        worker.async {
            self.pollable[zmqSocket] = Pollable(socket: socket, flags: flags, handler: handler)
        }
    }

    func stopPolling(socket: Socket) {
        guard let zmqSocket = socket.socket else {
            return
        }
        worker.async {
            self.pollable[zmqSocket] = nil
        }
    }

    func shutdown() {
        worker.async {
            self.pollMore = false
        }
    }

    struct Pollable {
        let socket: Socket
        let flags: PollingFlags
        let handler: EventHandler
    }

    private var pollable = [UnsafeMutableRawPointer: Pollable]() {
        didSet {
            if oldValue.isEmpty && !pollable.isEmpty {
                worker.async {
                    self.poll()
                }
            }
        }
    }
}

extension SocketPoller {
    func poll() {
        guard !pollable.isEmpty else {
            return
        }

        defer { pollAgainUnlessStopped() }

        var pollItems = pollable.map { (socket, pollable) in
            zmq_pollitem_t(socket: socket,
                           fd: 0,
                           events: pollable.flags.rawValue,
                           revents: 0)
        }

        let pollResult = pollItems.withUnsafeMutableBufferPointer { ptr in
            zmq_poll(ptr.baseAddress, Int32(pollable.count), 1)
        }

        guard pollResult != -1 else {
            return shutdown()
        }

        // Notify any listeners
        for item in pollItems {
            let flags = PollingFlags(rawValue: item.revents)
            if flags.contains(.pollIn) {
                if let readable = pollable[item.socket] {
                    readable.handler(readable.socket)
                }
            }
            if flags.contains(.pollOut) {
                if let writable = pollable[item.socket] {
                    writable.handler(writable.socket)
                }
            }
            if flags.contains(.pollErr) {
                if let errored = pollable[item.socket] {
                    errored.handler(errored.socket)
                }
            }
        }
    }

    func pollAgainUnlessStopped() {
        guard pollMore else {
            keepAlive = nil
            return
        }

        worker.async {
            self.poll()
        }
    }
}
