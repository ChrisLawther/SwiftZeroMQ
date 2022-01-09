import Foundation

public enum Endpoint {
    case tcp(interface: String, port: Int)
    case ipc(pathname: String)
    case inproc(name: String)
    // case pgm - not supported (yet)
    // case epgm - not supported (yet)
}

extension Endpoint {
    var path: String {
        switch self {
        case .tcp(interface: let interface, port: let port):
            return "tcp://\(interface):\(port)"
        case .ipc(pathname: let pathname):
            return "ipc://\(pathname)"
        case .inproc(name: let name):
            return "inproc://\(name)"
        }
    }
}
