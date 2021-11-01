import Foundation
import CZeroMQ

public enum SocketSendRecvOption: Int32 {
    case none
    case dontWait
    case sendMore
    case dontWaitSendMore

    // Looks pointless, but `#define`d values aren't visible to `case xxx = whatever`
    // whereas they are visible in this context:
    public var rawValue: Int32 {
        switch self {
            case .none: return 0
            case .dontWait: return ZMQ_DONTWAIT
            case .sendMore: return ZMQ_SNDMORE
            case .dontWaitSendMore: return ZMQ_DONTWAIT | ZMQ_SNDMORE
        }
    }
}
