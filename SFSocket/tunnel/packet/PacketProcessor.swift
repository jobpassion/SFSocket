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
   
    public init(){
        
    }
    public init(p:PacketProcessorProtocol) {
        self.provider = p
        SKit.logX("todo set UDPManager.shared.udpStack.outputFunc ", level: .Info)
       // UDPManager.shared.udpStack.outputFunc = output
    }
    public init(p:PacketProcessorProtocol,output:@escaping (([Data], [NSNumber]) -> ())) {
        self.provider = p
        SKit.logX("todo set UDPManager.shared.udpStack.outputFunc ", level: .Info)
        UDPManager.shared.udpStack.outputFunc = output
    }
    public func sendPackets(_ packets: [Data], protocols: [NSNumber]) {
       
        let manager = SFTCPConnectionManager.manager
        if manager.provider == nil {
            manager.provider = self
        }
       
        var tcppacket:[Data] = []
        for (index, packet) in packets.enumerated() {
            guard index < protocols.count else { break }
            
            //let desc = protocols[index].intValue==AF_INET ? "IPV4" : protocols[index]
            if protocols[index].int32Value == AF_INET {
                //AxLogger.log("\(packet) is ipv6 packet, don't support",level: .Warning)
                //let packet = packet as NSData
                
                
                
                
                
                let ipacket =  IPv4Packet(PacketData:packet)
                SKit.logX("incoming: \(ipacket.description)", level: .Info)
                switch Int32(ipacket.proto) {
                case IPPROTO_UDP:
                    
                   
                    
                    
                    let udp = UDPPacket.init(PacketData: ipacket.payloadData())
                    let srcport = udp.sourcePort
                    let destport = udp.destinationPort
                    //DNS process
                    if destport == 53 && ipacket.dstaddr == SKit.proxyIpAddr {
                        
                        if let c =  UDPManager.shared.clientTree.search(input: srcport) {
                            c.addQuery(packet: udp)
                        }else {
                            let dnsConnector = SFDNSForwarder.init(sip: ipacket.srcIP , dip: ipacket.dstIP, packet: udp)
                            let c = dnsConnector as SFUDPConnector
                            
                            UDPManager.shared.clientTree.insert(key: srcport, payload: c)
                            UDPManager.shared.udpClientIndex.append(srcport)
                            c.delegate = self
                        }
                        
                        
                        //report.currentTraffice.addTx(x: packet.count)
                    }else {
                        
                        if SFSettingModule.setting.udprelayer {
                            let v = protocols[index]
                            //leaks
                            if UDPManager.shared.udpStack.outputFunc != nil {
                                _ =  UDPManager.shared.udpStack.inputPacket(packet, version: v)
                            }
                            //drop
                        }else {
                            SKit.log("UDP:\(ipacket.description) not support ,drop", level: .Trace)
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
                    //report.currentTraffice.addTx(x: packet.count)
                    
                //break
                case IPPROTO_ICMP:
                    SKit.log("IPPROTO_ICMP packet found drop \(ipacket.description)",level: .Warning)
                    break
                default:
                    SKit.log("\(ipacket.proto) packet found drop ",level: .Warning)
                    break
                }
                
                //AxLogger.log("write to tun length:\(0) src:\(src) dst: \(dst) sendPackets packet packet data \(packet)" + (desc as! String) as String)
            }else if protocols[index].int32Value == AF_INET6{
                SKit.log("IPv6 packet currently don't support ...",level: .Info)
            }
            
            
            
            
        }
        //          逻辑有点复杂，每次写一个packet 太浪费CPU
        //            dispatch_async(dispatch_get_main_queue()){[unowned self] in
        //                    self.sendingPackets()
        //                }
        
        manager.device_read_handler_sendPackets3( packets) {[unowned self] (error) in
            self.provider?.didProcess()
            
        }
    }
}

extension PacketProcessor:OutgoingConnectorDelegate,TCPManagerProtocol {
    public func writeDatagrams(packets: Data, proto: Int32){
        provider?.writeDatagrams(packet: packets, proto: proto)
    }
    public func serverDidQuery(_ targetTunnel: SFUDPConnector, data : Data, close:Bool){
        provider?.writeDatagrams(packet: data, proto: AF_INET)
        UDPManager.shared.serverDidQuery(targetTunnel, data: data, close: close)
    }
    public func serverDidClose(_ targetTunnel: SFUDPConnector){
        UDPManager.shared.serverDidClose(targetTunnel)
    }
}
