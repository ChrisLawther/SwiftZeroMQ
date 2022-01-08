import Foundation

public enum Endpoint {
    case tcp(interface: String, port: Int)
    case ipc(name: String)
    case inproc(name: String)
}

extension Endpoint {
    var path: String {
        switch self {
        case .tcp(interface: let interface, port: let port):
            return "tcp://\(interface):\(port)"
        case .ipc(name: let name):
            return "ipc://\(name)"
        case .inproc(name: let name):
            return "inproc://\(name)"
        }
    }
}
