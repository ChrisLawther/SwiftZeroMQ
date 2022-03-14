import Foundation
import CZeroMQ

enum SocketType: Int32 {
    case request
    case reply
    case router
    case dealer

    case publish
    case subscribe
    case xpublish
    case xsubscribe

    case push
    case pull

    case pair

    case stream

    public var rawValue: Int32 {
        switch self {
        case .request:  return ZMQ_REQ
        case .reply:    return ZMQ_REP
        case .router:   return ZMQ_ROUTER
        case .dealer:   return ZMQ_DEALER

        case .publish:  return ZMQ_PUB
        case .subscribe: return ZMQ_SUB
        case .xpublish: return ZMQ_XPUB
        case .xsubscribe: return ZMQ_XSUB

        case .push:     return ZMQ_PUSH
        case .pull:     return ZMQ_PULL

        case .pair:     return ZMQ_PAIR

        case .stream:   return ZMQ_STREAM
        }
    }
}
