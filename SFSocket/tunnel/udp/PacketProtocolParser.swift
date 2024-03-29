import Foundation
import XSocket
protocol TransportProtocolParserProtocol {
    var packetData: Data! { get set }
    
    var offset: Int { get set }
    
    var bytesLength: Int { get }
    
    var payload: Data! { get set }
    
    func buildSegment(_ pseudoHeaderChecksum: UInt32)
}

/// Parser to process UDP packet and build packet.
class UDPProtocolParser: TransportProtocolParserProtocol {
    /// The source port.
    var sourcePort: XPort!
    
    /// The destination port.
    var destinationPort: XPort!
    
    /// The data containing the UDP segment.
    var packetData: Data!
    
    /// The offset of the UDP segment in the `packetData`.
    var offset: Int = 0
    
    /// The payload to be encapsulated.
    var payload: Data!
    
    /// The length of the UDP segment.
    var bytesLength: Int {
        return payload.count + 8
    }
    
    init() {}
    
    init?(packetData: Data, offset: Int) {
        guard packetData.count >= offset + 8 else {
            return nil
        }
        
        self.packetData = packetData
        self.offset = offset
        
        sourcePort = XPort(bytesInNetworkOrder: (packetData as NSData).bytes.advanced(by: offset))
        destinationPort = XPort(bytesInNetworkOrder: (packetData as NSData).bytes.advanced(by: offset + 2))
        
        payload = packetData.subdata(in: offset+8..<packetData.count)
    }
    
    func buildSegment(_ pseudoHeaderChecksum: UInt32) {
        sourcePort.withUnsafeBufferPointer {
            self.packetData.replaceSubrange(offset..<offset+2, with: $0)
        }
        destinationPort.withUnsafeBufferPointer {
            self.packetData.replaceSubrange(offset+2..<offset+4, with: $0)
        }
        var length = NSSwapHostShortToBig(UInt16(bytesLength))
        withUnsafeBytes(of: &length) {
            packetData.replaceSubrange(offset+4..<offset+6, with: $0)
        }
        packetData.replaceSubrange(offset+8..<offset+8+payload.count, with: payload)
        packetData.resetBytes(in: offset+6..<offset+8)
        
        // Todo: compute checksum
        //        var checksum = Checksum.computeChecksum(datagram, from: 0, to: nil, withPseudoHeaderChecksum: pseudoHeaderChecksum)
        //        datagram.replaceBytesInRange(NSRange(location: 6, length: 2), withBytes: &checksum)
    }
}
