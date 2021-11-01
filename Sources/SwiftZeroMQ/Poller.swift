import Foundation
import CZeroMQ

public struct PollingFlags: OptionSet {
    public var rawValue: Int16

    public init(rawValue: Int16) {
        self.rawValue = rawValue
    }

    public static let pollIn = PollingFlags(rawValue: Int16(ZMQ_POLLIN))
    public static let pollOut = PollingFlags(rawValue: Int16(ZMQ_POLLOUT))
    public static let pollErr = PollingFlags(rawValue: Int16(ZMQ_POLLERR))
    public static let none: PollingFlags = []
}

extension Socket: Hashable {
    public static func == (lhs: Socket, rhs: Socket) -> Bool {
        return lhs.socket == rhs.socket
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self).hashValue)
    }
}

enum PollTimeout {
    case immediate
    case indefinate
    case microSeconds(Int)
}

extension PollTimeout {
    var value: Int {
        switch self {
        case .immediate:
            return 0
        case .indefinate:
            return -1
        case .microSeconds(let ms):
            return ms
        }
    }
}

class Poller {

    // TODO: This needs to be ordered (for repeatability), but we'd also like
    // some map-like behaviour for updating / removing entries
    private var sockets = [Socket: PollingFlags]()

    public func register(socket: Socket, flags: PollingFlags = [.pollIn, .pollOut]) throws {
        guard flags != .none else {
            // TODO: Remove any existing registration
            return
        }

        sockets[socket] = flags
    }

    public func unregister(socket: Socket) {
        sockets[socket] = nil
    }

    public func poll(timeout: PollTimeout) -> Result<(readable: [Socket], writable: [Socket], errored: [Socket]), Error> {
        let polling = PollableItems(sockets)
        return polling.poll(timeout: timeout.value)
//        let pollItems = Self.pollItems(from: sockets)
//        defer { pollItems.deallocate() }
//
//        let timeout = Int(timeout ?? -1)
//
//        let activity =  zmq_poll(pollItems, Int32(sockets.count), timeout)
//
//        guard activity >= 0 else {
//            return .failure(ZMQError.lastError())
//        }
//
//        print("Activity on \(activity) sockets")
//        return .success(socketEvents(from: pollItems))
    }
}

private extension Poller {
//    static func pollItems(from sockets: [(Socket, PollingFlags)]) -> UnsafeMutablePointer<zmq_pollitem_t> {
//
//        let items = UnsafeMutablePointer<zmq_pollitem_t>.allocate(capacity: sockets.count)
//
//        for (idx, (socket, flags)) in sockets.enumerated() {
//            var item = zmq_pollitem_t()
//            item.socket = socket.socket
//            item.events = Int16(flags.rawValue)
//            items[idx] = item
//        }
//
//        return items
//    }

//    func socketEvents(from pollItems: UnsafeMutablePointer<zmq_pollitem_t>) -> (readable: [Socket], writable: [Socket], errored: [Socket]) {
//
//        for polledItem in pollItems {
//            let flags = PollingFlags(rawValue: Int32(item.revents))
//        }
//
//        let socketsAndEvents = sockets.enumerated().map { (idx, socket) -> (socket: Socket, flags: PollingFlags) in
//            let item = pollItems[idx]
//            let flags = PollingFlags(rawValue: item.revents)
//            return (socket.0, flags)
//        }
//
//        let readable = socketsAndEvents.filter { $0.flags.contains(.pollIn) } .map { $0.socket }
//        let writable = socketsAndEvents.filter { $0.flags.contains(.pollOut) } .map { $0.socket }
//        let errored = socketsAndEvents.filter { $0.flags.contains(.pollErr) } .map { $0.socket }
//
//        return (readable: readable, writable: writable, errored: errored)
//    }
}

class PollableItems {
    let pollItems: UnsafeMutablePointer<zmq_pollitem_t>
    private let sockets: [Socket]

    init(_ socketsAndFlags: [Socket: PollingFlags]) {
        pollItems = UnsafeMutablePointer<zmq_pollitem_t>.allocate(capacity: socketsAndFlags.count)
        var sockets = [Socket]()

        for (idx, (socket, flags)) in socketsAndFlags.enumerated() {
            var item = zmq_pollitem_t()
            item.socket = socket.socket
            item.events = Int16(flags.rawValue)
            sockets.append(socket)
            pollItems[idx] = item
        }
        self.sockets = sockets
    }

    func poll(timeout: Int = -1) -> Result<(readable: [Socket], writable: [Socket], errored: [Socket]), Error> {
        let activity =  zmq_poll(pollItems, Int32(sockets.count), timeout)

        guard activity >= 0 else {
            return .failure(ZMQError.lastError())
        }

        let flags = sockets.enumerated().map { row in
            PollingFlags(rawValue: pollItems[row.offset].revents)
        }

        let readable = sockets.enumerated().filter { flags[$0.offset].contains(.pollIn) } .map { $0.element }
        let writable = sockets.enumerated().filter { flags[$0.offset].contains(.pollOut) } .map { $0.element }
        let errored = sockets.enumerated().filter { flags[$0.offset].contains(.pollErr) } .map { $0.element }

        return .success((readable: Array(readable),
                         writable: Array(writable),
                         errored: Array(errored)))
    }

    deinit {
        pollItems.deallocate()
    }
}
