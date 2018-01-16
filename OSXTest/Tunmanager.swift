//
//  Tunmanager.swift
//  XTunnel
//
//  Created by yarshure on 2017/9/26.
//  Copyright © 2017年 yarshure. All rights reserved.
//

import Cocoa
import SFSocket
import DarwinCore
class Tunmanager: NSObject {

    // MARK: Properties
    
    /// The virtual address of the tunnel.
    var tunnelAddress: String?
    
    /// The name of the UTUN interface.
    var utunName: String?
    
    /// A dispatch source for the UTUN interface socket.
    var utunSource: DispatchSourceRead?
    
    /// A flag indicating if reads from the UTUN interface are suspended.
    var isSuspended = false
    /// PacketProcessor
    var processor:PacketProcessor = PacketProcessor()
    func open() ->Bool {
        guard setupVirtualInterface(address: "240.7.1.9") else {
            return false
        }
        processor.provider = self
      
        return false
    }
    /// Create a UTUN interface.
    func createTUNInterface() -> Int32 {
        
        let utunSocket = socket(PF_SYSTEM, SOCK_DGRAM, SYSPROTO_CONTROL)
        guard utunSocket >= 0 else {
            simpleTunnelLog("Failed to open a kernel control socket")
            return -1
        }
        
        let controlIdentifier = getUTUNControlIdentifier(utunSocket)
        guard controlIdentifier > 0 else {
            simpleTunnelLog("Failed to get the control ID for the utun kernel control")
            close(utunSocket)
            return -1
        }
        
        // Connect the socket to the UTUN kernel control.
        var socketAddressControl = sockaddr_ctl(sc_len: UInt8(MemoryLayout<sockaddr_ctl>.size), sc_family: UInt8(AF_SYSTEM), ss_sysaddr: UInt16(AF_SYS_CONTROL), sc_id: controlIdentifier, sc_unit: 0, sc_reserved: (0, 0, 0, 0, 0))
        
        let connectResult = withUnsafePointer(to: &socketAddressControl) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(utunSocket, $0, socklen_t(MemoryLayout.size(ofValue: socketAddressControl)))
            }

           // connect(utunSocket, UnsafePointer<sockaddr>($0), socklen_t(MemoryLayout.size(ofValue: socketAddressControl)))
        }
        
        if connectResult < 0 {
            let errorString = String(cString: strerror(errno))
            simpleTunnelLog("Failed to create a utun interface: \(errorString)")
            close(utunSocket)
            return -1
        }
        
        return utunSocket
    }

    /// Get the name of a UTUN interface the associated socket.
    func getTUNInterfaceName(utunSocket: Int32) -> String? {
        var buffer = [Int8](repeating: 0, count: Int(IFNAMSIZ))
        var bufferSize: socklen_t = socklen_t(buffer.count)
        let resultCode = getsockopt(utunSocket, SYSPROTO_CONTROL, getUTUNNameOption(), &buffer, &bufferSize)
        if  resultCode < 0 {
            let errorString = String(cString: strerror(errno))
            simpleTunnelLog("getsockopt failed while getting the utun interface name: \(errorString)")
            return nil
        }
        return String(cString: &buffer)
    }
    
    /// Set up the UTUN interface, start reading packets.
    func setupVirtualInterface(address: String) -> Bool {
        let utunSocket = createTUNInterface()
        guard let interfaceName = getTUNInterfaceName(utunSocket: utunSocket), utunSocket >= 0 &&
                setUTUNAddress(interfaceName, address)
            else { return false }
        
        startTunnelSource(utunSocket: utunSocket)
        utunName = interfaceName
        return true
    }
    /// Start reading packets from the UTUN interface.
    func startTunnelSource(utunSocket: Int32) {
        guard setSocketNonBlocking(utunSocket) else { return }
        //fixme
        //DispatchSource.makeReadSource(fileDescriptor: UInt(utunSocket))
        let newSource = DispatchSource.makeReadSource(fileDescriptor: utunSocket)
        newSource.setCancelHandler  {
            close(utunSocket)
            return

        }
        newSource.setEventHandler {
            self.readPackets()
        }
        newSource.resume()
        utunSource = newSource as! DispatchSource

    }
    
    /// Read packets from the UTUN interface.
    func readPackets() {
        guard let source = utunSource else { return }
        var packets = [NSData]()
        var protocols = [NSNumber]()
        
        // We use a 2-element iovec list. The first iovec points to the protocol number of the packet, the second iovec points to the buffer where the packet should be read.
        var buffer = [UInt8](repeating:0, count: 8192)
        var protocolNumber: UInt32 = 0
        var iovecList = [ iovec(iov_base: &protocolNumber, iov_len: MemoryLayout.size(ofValue: protocolNumber)), iovec(iov_base: &buffer, iov_len: buffer.count) ]
        let iovecListPointer = UnsafeBufferPointer<iovec>(start: &iovecList, count: iovecList.count)
        let utunSocket = Int32(source.handle)
        
        repeat {
            let readCount = readv(utunSocket, iovecListPointer.baseAddress, Int32(iovecListPointer.count))
            
            guard readCount > 0 || errno == EAGAIN else {
                if  readCount < 0 {
                    let errorString = String(cString: strerror(errno))
                    simpleTunnelLog("Got an error on the utun socket: \(errorString)")
                }
                source.cancel()
                break
            }
            
            guard readCount > MemoryLayout.size(ofValue: protocolNumber) else { break }
            
            if protocolNumber.littleEndian == protocolNumber {
                protocolNumber = protocolNumber.byteSwapped
            }
            if protocolNumber == AF_INET {
                protocols.append(NSNumber(value: protocolNumber))
                packets.append(NSData(bytes: &buffer, length: readCount - MemoryLayout.size(ofValue: protocolNumber)))

            }else {
                //UDP
            }
            
            // Buffer up packets so that we can include multiple packets per message. Once we reach a per-message maximum send a "packets" message.
            if packets.count == 32 {
                //fixme
                simpleTunnelLog("Got packets")
                processor.sendPackets(packets as [Data], protocols: protocols)
               
                packets = [NSData]()
                protocols = [NSNumber]()
                if isSuspended { break } // If the entire message could not be sent and the connection is suspended, stop reading packets.
            }
        } while true
        
        // If there are unsent packets left over, send them now.
        if packets.count > 0 {
            simpleTunnelLog("Got packets \(packets)")
            
            processor.sendPackets(packets as [Data], protocols: protocols)
            //tunnel?.sendPackets(packets, protocols: protocols, forConnection: identifier)
        }
    }


//    // MARK: Connection
//
    /// Abort the connection.
    func abort(error: Int = 0) {

        closeConnection()
    }
//
    /// Close the connection.
    func closeConnection() {
   

        utunSource!.cancel()
        utunName = nil

    }
//
    /// Stop reading packets from the UTUN interface.
    func suspend() {
        isSuspended = true
        if let source = utunSource {
            source.suspend()
        }
    }

    /// Resume reading packets from the UTUN interface.
   func resume() {
        isSuspended = false
        if let source = utunSource {
            source.resume()
            readPackets()
        }
    }

    /// Write packets and associated protocols to the UTUN interface.
    func sendPackets(packets: [Data], protocols: [NSNumber]) {
        guard let source = utunSource else { return }
        let utunSocket = Int32(source.handle)

        for (index, packet) in packets.enumerated() {

            guard index < protocols.count else { break }
            
            var protocolNumber = protocols[index].uint32Value.bigEndian
            
            
            var buffer:UnsafeMutableRawPointer?
            
            var ptr :UnsafePointer<Any>?
            
            packet.withUnsafeBytes({ (p:UnsafePointer) -> Void in
                ptr = p
            })
            buffer = UnsafeMutableRawPointer.init(mutating: ptr)
            var iovecList = [ iovec(iov_base: &protocolNumber, iov_len: MemoryLayout.size(ofValue: protocolNumber)), iovec(iov_base: buffer, iov_len: packet.count) ]
            
            let writeCount = writev(utunSocket, &iovecList, Int32(iovecList.count))
            if writeCount < 0 {
                let errorString = String.init(cString: strerror(errno))
                simpleTunnelLog("Got an error while writing to utun: \(errorString)")
                
            }
            else if writeCount < packet.count + MemoryLayout.size(ofValue: protocolNumber) {
                simpleTunnelLog("Wrote \(writeCount) bytes of a \(packet.count) byte packet to utun")
            }
        }
    }
    
    
}
extension Tunmanager:PacketProcessorProtocol{
    func writeDatagram(packet: Data, proto: Int32) {
        self.sendPackets(packets: [packet], protocols: [NSNumber.init(value: proto)])
    }
    
    func writeDatagrams(packet: [Data], proto: [NSNumber]) {
        self.sendPackets(packets: packet, protocols: proto)
    }
    
    func didProcess() {
        simpleTunnelLog("didProcess ...")
    }
    
    
}
