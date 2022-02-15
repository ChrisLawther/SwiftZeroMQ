import Foundation

//  For tcp connections, the interface should be one of:
//  * * - wildcard meaning "all available interfaces"
//  * The primary address (IPv4 or IPv6) of the interface, in *numeric* form
//  * The non-portable interface name as defined by the operating system (e.g. "eth0")


/// <#Description#>
/// - Parameter arg: <#arg description#>
/// - Returns: <#description#>
func wibble(_ arg: Int) -> Bool {
    return true
}

/// Describes the supported connection endpoints
public enum Endpoint {
    /// TCP, for communication between processes running on the same or different machines
    /// 
    /// The interface should be one of:
    /// * The wildcard `*` meaning "all available interfaces"
    /// * The primary address (IPv4 or IPv6) of the interface, in *numeric* form
    /// * The non-portable interface name as defined by the operating system (e.g. "eth0")
    case tcp(interface: String, port: Int)
    /// Inter-process-communication, works between processes on current machine
    /// - Parameter pathname: Path to the Unix-domain socket to use
    case ipc(pathname: String)
    /// In-process, for communication between threads within the same process
    /// - Parameter name: A name for,...
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
