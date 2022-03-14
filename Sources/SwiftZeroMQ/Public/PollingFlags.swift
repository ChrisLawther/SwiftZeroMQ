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
