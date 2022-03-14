import Foundation
import CZeroMQ

public enum SocketSendRecvOption: Int32 {
    /// Blocking, only (or final) message part
    case none
    /// Non-blocking, only (or final) message part
    case dontWait
    /// Blocking, more parts to follow
    case sendMore
    /// Non-blocking, more parts to follow
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
