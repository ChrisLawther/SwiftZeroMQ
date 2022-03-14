import Foundation
import CZeroMQ

extension Socket: WriteableSocket {
    public func send(_ data: Data, options: SocketSendRecvOption) throws {
        try data.withUnsafeBytes { rawBufferPointer -> Void in
            let result = zmq_send(socket!, rawBufferPointer.baseAddress, data.count, options.rawValue)

            if result == -1 {
                throw ZMQError.lastError()
            }
        }
    }
}
