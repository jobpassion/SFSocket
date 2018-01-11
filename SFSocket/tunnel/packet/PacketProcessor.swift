//
//  PacketProcessor.swift
//  SFSocket
//
//  Created by yarshure on 2018/1/4.
//  Copyright © 2018年 Kong XiangBo. All rights reserved.
//

import Foundation
import XRuler
import XFoundation
public class PacketProcessor {
    /// Write packets and associated protocols to the UTUN interface.
    public var complete:(()->Void)?
    public var provider:PacketProcessorProtocol?
    var packetsQueue:[Data] = []
    var processIng:Bool = false
    let report = SFVPNStatistics.shared
    let udpManager = UDPManager()
    public init(){
        udpManager.udpStack.outputFunc = generateOutputBlock()
    }
    public init(p:PacketProcessorProtocol) {
        self.provider = p
        udpManager.udpStack.outputFunc = generateOutputBlock()
    }
    public init(p:PacketProcessorProtocol,output:@escaping (([Data], [NSNumber]) -> ())) {
        self.provider = p
       
        udpManager.udpStack.outputFunc = output
    }
    public func sendPackets(_ packets: [Data], protocols: [NSNumber]) {
       
        let manager = SFTCPConnectionManager.shared
        if manager.provider == nil {
            manager.provider = self
        }
       
        var tcppacket:[Data] = []
        for (index, packet) in packets.enumerated() {
            guard index < protocols.count else { break }
            if protocols[index].int32Value == AF_INET {

                
                let ipacket =  IPv4Packet(PacketData:packet)
                SKit.logX("incoming " + ipacket.description, level: .Info)
                switch Int32(ipacket.proto) {
                case IPPROTO_UDP:

                    let udp = UDPPacket.init(PacketData: ipacket.payloadData())
                    let srcport = udp.sourcePort
                    let destport = udp.destinationPort
                    //DNS process
                    if destport == 53 && ipacket.dstaddr == SKit.proxyIpAddr {
                        
                        if let c =  udpManager.clientTree.search(input: srcport) {
                            c.addQuery(packet: udp)
                        }else {
                            let dnsConnector = SFDNSForwarder.init(sip: ipacket.srcIP , dip: ipacket.dstIP, packet: udp)
                            let c = dnsConnector as SFUDPConnector
                            
                            udpManager.clientTree.insert(key: srcport, payload: c)
                            udpManager.udpClientIndex.append(srcport)
                            c.delegate = self
                        }
                        
                        
                        report.currentTraffice.addTx(x: packet.count)
                    }else {
                        
                        if SFSettingModule.setting.udprelayer {
                            let v = protocols[index]
                            
                            if udpManager.udpStack.outputFunc != nil {
                                _ =  udpManager.udpStack.inputPacket(packet, version: v)
                            }
                            report.currentTraffice.addTx(x: packet.count)
                        }else {
                            //drop
                            SKit.log("UDP:not support ,drop " + ipacket.description, level: .Trace)
                        }
                        
                    }
                    
                case IPPROTO_TCP:
                    
                    
                    //let sD = packet.subdata(in: Range(4*5 ..< 4*5 + 2))
                    //_  = UInt16(data2Int(sD, len: 2))
                    
                    if  manager.lwip_init_finished == false {
                        SKit.log("lwip init not finished,waitting",level: .Info)
                        usleep(500)
                    }
                    tcppacket.append(packet)
                    report.currentTraffice.addTx(x: packet.count)
                    
                //break
                case IPPROTO_ICMP:
                    SKit.log("IPPROTO_ICMP packet found drop " + ipacket.description,level: .Warning)
                    break
                default:
                    SKit.log("packet found drop ",level: .Warning)
                    break
                }
            }else if protocols[index].int32Value == AF_INET6{
                SKit.log("IPv6 packet currently don't support ...",level: .Info)
            }
        }
        //          逻辑有点复杂，每次写一个packet 太浪费CPU
        //            dispatch_async(dispatch_get_main_queue()){[unowned self] in
        //                    self.sendingPackets()
        //                }
        //processIng = true
        manager.device_read_handler_sendPackets3( packets) {[unowned self] (error) in
            
            if self.processIng {
                let  protocols = [NSNumber](repeating: NSNumber.init(value: AF_INET), count: self.packetsQueue.count)
                
                self.provider?.writeDatagrams(packet: self.packetsQueue, proto: protocols)
                self.packetsQueue.removeAll()
                self.provider?.didProcess()
                self.processIng = false
            }
            
        }
    }
}

extension PacketProcessor:OutgoingConnectorDelegate,TCPManagerProtocol {
    public func writeDatagram(packets: Data, proto: Int32){
        
        if processIng {
            packetsQueue.append(packets)
            
        }else {
            
            provider?.writeDatagram(packet: packets, proto: proto)
        }
        report.currentTraffice.addRx(x: packets.count)
    }
    public func serverDidQuery(_ targetTunnel: SFUDPConnector, data : Data, close:Bool){
        provider?.writeDatagram(packet: data, proto: AF_INET)
        report.currentTraffice.addRx(x: data.count)
        udpManager.serverDidQuery(targetTunnel, data: data, close: close)
    }
    public func serverDidClose(_ targetTunnel: SFUDPConnector){
        udpManager.serverDidClose(targetTunnel)
    }
}
extension PacketProcessor {
    public func generateOutputBlock() -> ([Data], [NSNumber]) -> () {
        return { [weak self] packets, versions in
            if let strong = self {
                strong.provider?.writeDatagrams(packet: packets, proto: versions)
                
            }
            
        }
    }
   
    

}
