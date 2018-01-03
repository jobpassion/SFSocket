//
//  Tunnel.swift
//  OSXTest
//
//  Created by yarshure on 2018/1/3.
//  Copyright © 2018年 Kong XiangBo. All rights reserved.
//

import Foundation
import SFSocket
import XRuler
class Tunnel{
    /// The maximum size of a single tunneled IP packet.
    class var packetSize: Int { return 8192 }
    /// The maximum number of IP packets in a single SimpleTunnel data message.
    class var maximumPacketsPerMessage: Int { return 32 }
    /// Send a Packets message on the tunnel connection.
     init()  {
        UDPManager.shared.udpStack.outputFunc = self.generateOutputBlock()
    }
    func sendPackets(_ packets: [Data], protocols: [NSNumber], forConnection connectionIdentifier: Int){
        
        
        let manager = SFTCPConnectionManager.manager
        if manager.provider == nil {
            manager.provider = self
        }
        var tcppacket:[Data] = []
        for (index, packet) in packets.enumerated() {
            guard index < protocols.count else { break }
            simpleTunnelLog("receive \(packet as NSData)")
            //let desc = protocols[index].intValue==AF_INET ? "IPV4" : protocols[index]
            if protocols[index].int32Value == AF_INET {
                //AxLogger.log("\(packet) is ipv6 packet, don't support",level: .Warning)
                //let packet = packet as NSData
                
                
                let proto = dataToInt(packet.subdata(in: Range ( 4*2+1 ..< 4*2+2)))
                //AxLogger.log("TUN Read:\(packet as NSData) \(proto)", level: .Debug)
                //let src = datatoIP(packet.subdataWithRange(NSRange.init(location: 4*3, length: 4)))
                let dst = datatoIP(packet.subdata(in: Range( 4*4 ..< 4*5)))
                //subdataWithRange(NSRange.init(location: 4*4, length: 4)))
                //debugLog("tcp packet src:\(src),dst:\(dst)")
                
                switch proto {
                case IPPROTO_UDP:
                    //AxLogger.log("IPPROTO_UDP length:\(packet.length) src:\(src) dst: \(dst) sendPackets packet packet data \(packet)" + (desc as! String) as String)
                    let ip =  IPv4Packet(PacketData:packet)
                    let destIP = ip.destinationIP
                    
                    
                    let udp = UDPPacket.init(PacketData: ip.payloadData())
                    let srcport = udp.sourcePort
                    let destport = udp.destinationPort
                    if destport == 53 && dst == SKit.proxyIpAddr {
                        
                        if let c =  UDPManager.shared.clientTree.search(input: srcport) {
                            c.addQuery(packet: udp)
                        }else {
                            let dnsConnector = SFDNSForwarder.init(sip: ip.srcIP , dip: ip.destinationIP, packet: udp)
                            let c = dnsConnector as SFUDPConnector
                            
                            UDPManager.shared.clientTree.insert(key: srcport, payload: c)
                            UDPManager.shared.udpClientIndex.append(srcport)
                            c.delegate = self as OutgoingConnectorDelegate
                        }
                        
                        
                        //report.currentTraffice.addTx(x: packet.count)
                    }else {
                        
                        if SFSettingModule.setting.udprelayer {
                            let v = protocols[index]
                            //leaks
                            _ =  UDPManager.shared.udpStack.inputPacket(packet, version: v)
                        }else {
                            VLog.log("UDP:\(destIP):\(destport) not support ,drop", level: .Trace)
                        }
                        
                    }
                    
                    
                    
                    
                case IPPROTO_TCP:
                    
                    
                    //let sD = packet.subdata(in: Range(4*5 ..< 4*5 + 2))
                    //_  = UInt16(data2Int(sD, len: 2))
                    
                    if  manager.lwip_init_finished == false {
                        VLog.log("lwip init not finished,waitting",level: .Info)
                        usleep(500)
                    }
                    tcppacket.append(packet)
                    //report.currentTraffice.addTx(x: packet.count)
                    
                //break
                case IPPROTO_ICMP:
                    VLog.log("IPPROTO_ICMP packet found drop \(packet)",level: .Warning)
                    break
                default:
                    VLog.log("\(proto) packet found drop ",level: .Warning)
                    break
                }
                
                //AxLogger.log("write to tun length:\(0) src:\(src) dst: \(dst) sendPackets packet packet data \(packet)" + (desc as! String) as String)
            }else if protocols[index].int32Value == AF_INET6{
                VLog.log("IPv6 packet currently don't support ...",level: .Info)
            }
            
            
            
            
        }
      
        
        manager.device_read_handler_sendPackets3( packets) { (error) in
            VLog.log("packet send ok", level: .Info)
        }
    }
    
    public func generateOutputBlock() -> ([Data], [NSNumber]) -> () {
        return {  packets, versions in
            ServerTunnelConnection.shared.sendPackets(packets, protocols: versions)
            
        }
    }
}
extension Tunnel:OutgoingConnectorDelegate{
    func serverDidQuery(_ targetTunnel: SFUDPConnector, data: Data, close: Bool) {
        if data.count > 0 {
            let c = targetTunnel as! SFDNSForwarder
            let srcport = c.clientPort
            if close {
                c.shutdownSocket()
                VLog.log("delete \(srcport) udp connect", level: .Info)
                UDPManager.shared.clientTree.delete(key: srcport)
                let index:Int = UDPManager.shared.indexFor(port: srcport)
                if index != -1 {
                    UDPManager.shared.udpClientIndex.remove(at: index)
                }
                
                
            }else {
                VLog.log("\(srcport) udp connect living", level: .Info)
            }
            UDPManager.shared.cleanUDPConnector(force: false)
            
            
            //NSLog("write udp packet %@ ", data)
            var packets = [Data]()
            var protocols = [NSNumber]()
            packets.append(data)
            protocols.append(NSNumber(value: AF_INET))
            //tunnel?.sendPackets(packets, protocols: protocols, forConnection: identifier)
            
            //report.currentTraffice.addRx(x: data.count)
            ServerTunnelConnection.shared.sendPackets(packets, protocols: protocols)
           // packetFlow.writePackets(packets, withProtocols: protocols)
            
        }
    }
    
    func serverDidClose(_ targetTunnel: SFUDPConnector) {
        let c = targetTunnel as! SFDNSForwarder
        let srcport = c.clientPort
        UDPManager.shared.clientTree.delete(key: srcport)
        let index:Int = UDPManager.shared.indexFor(port: srcport)
        if index != -1 {
            UDPManager.shared.udpClientIndex.remove(at: index)
        }
        c.shutdownSocket()
    }
    
    
}
extension Tunnel:TCPManagerProtocol {
    func writeDatagrams(packets : Data,proto:Int32){
        ServerTunnelConnection.shared.sendPackets([packets], protocols: [NSNumber.init(value: proto)])
    }
}
