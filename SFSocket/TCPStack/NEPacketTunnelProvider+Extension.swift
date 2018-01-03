//
//  NEPacketTunnelProvider+Extension.swift
//  SFSocket
//
//  Created by 孔祥波 on 07/04/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//

import Foundation
import NetworkExtension
import AxLogger
import XRuler
extension NEPacketTunnelProvider{
    public func logStopReason( reason: NEProviderStopReason){
        var reasonString:String
        switch reason {
            /*! @const NEProviderStopReasonNone No specific reason. */
        case .none:
            reasonString = "No specific "
        case .userInitiated:
            reasonString = "user stopped"
        case .providerFailed:
            reasonString = "The provider failed"
            /*! @const NEProviderStopReasonNoNetworkAvailable There is no network connectivity. */
        case .noNetworkAvailable:
            reasonString = " no network"/*! @const NEProviderStopReasonUnrecoverableNetworkChange The device attached to a new network. */
        case .unrecoverableNetworkChange:
            reasonString = "device attached to a new network"/*! @const NEProviderStopReasonProviderDisabled The provider was disabled. */
        case .providerDisabled:
            reasonString = "provider was disabled"
            /*! @const NEProviderStopReasonAuthenticationCanceled The authentication process was cancelled. */
        case .authenticationCanceled:
            reasonString = "The authentication process was cancelled"
            /*! @const NEProviderStopReasonConfigurationFailed The provider could not be configured. */
        case .configurationFailed:
            reasonString = "The provider could not be configured."
            /*! @const NEProviderStopReasonIdleTimeout The provider was idle for too long. */
        case .idleTimeout:
            reasonString = "The provider was idle for too long"
            /*! @const NEProviderStopReasonConfigurationDisabled The associated configuration was disabled. */
        case .configurationDisabled:
            reasonString = "The associated configuration was disabled."
            /*! @const NEProviderStopReasonConfigurationRemoved The associated configuration was deleted. */
        case .configurationRemoved:
            reasonString = "The associated configuration was deleted."
            /*! @const NEProviderStopReasonSuperceded A high-priority configuration was started. */
        case .superceded:
            reasonString = "A high-priority configuration was started."
            /*! @const NEProviderStopReasonUserLogout The user logged out. */
        case .userLogout:
            reasonString = "The user logged out."
            /*! @const NEProviderStopReasonUserSwitch The active user changed. */
        case .userSwitch:
            reasonString = "The active user changed."
            /*! @const NEProviderStopReasonConnectionFailed Failed to establish connection. */
        case .connectionFailed:
            reasonString = "Failed to establish connection."
        }
        alertMessage(message: "stoping: \(reasonString)",reason: reason)
        //#displayMessage
        
    }
    public func alertMessage(message:String,reason:NEProviderStopReason){
        if #available(iOSApplicationExtension 10.0, *) {
            //VPN can alert
            if reason != .userInitiated {
                if #available(OSXApplicationExtension 10.12, *) {
                    displayMessage(message, completionHandler: { (fin) in
                        
                    })
                } else {
                    // Fallback on earlier versions
                }
            }
            
        }
        AxLogger.log(message,level:.Info)
    }
    public func generateOutputBlock() -> ([Data], [NSNumber]) -> () {
        return { [weak self] packets, versions in
            if let strong = self {
                strong.packetFlow.writePackets(packets as [Data], withProtocols: versions)
            }
            
        }
    }
  
    
    
    /// Write packets and associated protocols to the UTUN interface.
    public func processPackets(packets: [Data], protocols: [NSNumber]) {
        let manager = SFTCPConnectionManager.manager
        if manager.provider == nil {
            manager.provider = self
        }
        if reasserting {
            AxLogger.log(" reasserting..., Drop Packets",level: .Notify)
            //return
        }
        var tcppacket:[Data] = []
        for (index, packet) in packets.enumerated() {
            guard index < protocols.count else { break }
            
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
                            c.delegate = self
                        }
                        
                        
                        //report.currentTraffice.addTx(x: packet.count)
                    }else {
                        
                        if SFSettingModule.setting.udprelayer {
                            let v = protocols[index]
                            //leaks
                            _ =  UDPManager.shared.udpStack.inputPacket(packet, version: v)
                        }else {
                            AxLogger.log("UDP:\(destIP):\(destport) not support ,drop", level: .Trace)
                        }
                        
                    }
                    
                    
                    
                    
                case IPPROTO_TCP:
                    
                    
                    //let sD = packet.subdata(in: Range(4*5 ..< 4*5 + 2))
                    //_  = UInt16(data2Int(sD, len: 2))
                    
                    if  manager.lwip_init_finished == false {
                        AxLogger.log("lwip init not finished,waitting",level: .Info)
                        usleep(500)
                    }
                    tcppacket.append(packet)
                    //report.currentTraffice.addTx(x: packet.count)
                    
                //break
                case IPPROTO_ICMP:
                    AxLogger.log("IPPROTO_ICMP packet found drop \(packet)",level: .Warning)
                    break
                default:
                    AxLogger.log("\(proto) packet found drop ",level: .Warning)
                    break
                }
                
                //AxLogger.log("write to tun length:\(0) src:\(src) dst: \(dst) sendPackets packet packet data \(packet)" + (desc as! String) as String)
            }else if protocols[index].int32Value == AF_INET6{
                AxLogger.log("IPv6 packet currently don't support ...",level: .Info)
            }
            
            
            
            
        }
        //          逻辑有点复杂，每次写一个packet 太浪费CPU
        //            dispatch_async(dispatch_get_main_queue()){[unowned self] in
        //                    self.sendingPackets()
        //                }
        
        manager.device_read_handler_sendPackets3( packets) {[unowned self] (error) in
            self.packetFlow.readPackets {[unowned self] inPackets, inProtocols in
                self.processPackets(packets: inPackets, protocols: inProtocols)
            }
        }
    }
    public func startHandlingPackets() {
        
        
        packetFlow.readPackets { [unowned self ] inPackets, inProtocols in
            //if let s = self {
            self.processPackets(packets: inPackets, protocols: inProtocols)
            //}
            
        }
        
    }
 
}
extension NEPacketTunnelProvider:TCPManagerProtocol {
    public func writeDatagrams(packets : Data,proto:Int32){
        //cpu very high when traffic very high
        // inqueue ?
        if reasserting {
            AxLogger.log(" reasserting..., Drop Packets",level: .Info)
            //return
        }
        //report.currentTraffice.addRx(x: packets.count)
        
        
        let r = self.packetFlow.writePackets([packets], withProtocols: [NSNumber(value: proto)])
        if !r {
            AxLogger.log("writeDatagrams write tcp packet return false",level: .Error)
        }
        
    }
}
extension NEPacketTunnelProvider:OutgoingConnectorDelegate {
    public func serverDidQuery(_ targetTunnel: SFUDPConnector, data : Data,close:Bool){
        
        if reasserting {
            AxLogger.log(" reasserting..., Drop Packets",level: .Notify)
            return
        }
        if data.count > 0 {
            let c = targetTunnel as! SFDNSForwarder
            let srcport = c.clientPort
            if close {
                c.shutdownSocket()
                AxLogger.log("delete \(srcport) udp connect", level: .Info)
                 UDPManager.shared.clientTree.delete(key: srcport)
                let index:Int = UDPManager.shared.indexFor(port: srcport)
                if index != -1 {
                     UDPManager.shared.udpClientIndex.remove(at: index)
                }
                
                
            }else {
                AxLogger.log("\(srcport) udp connect living", level: .Info)
            }
            UDPManager.shared.cleanUDPConnector(force: false)
            
            
            //NSLog("write udp packet %@ ", data)
            var packets = [Data]()
            var protocols = [NSNumber]()
            packets.append(data)
            protocols.append(NSNumber(value: AF_INET))
            //tunnel?.sendPackets(packets, protocols: protocols, forConnection: identifier)
            
            //report.currentTraffice.addRx(x: data.count)
            
            packetFlow.writePackets(packets, withProtocols: protocols)
            
        }
    }
    
    public func serverDidClose(_ targetTunnel: SFUDPConnector){
        
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
extension NEPacketTunnelProvider{
    public func reportTask() {
        let report = SFVPNStatistics.shared
        report.lastTraffice.tx = report.currentTraffice.tx
        report.lastTraffice.rx = report.currentTraffice.rx
        let snapShot = SFTraffic()
        snapShot.tx = report.currentTraffice.tx
        snapShot.rx = report.currentTraffice.rx
        report.netflow.update(snapShot, type: .total)
        
        report.currentTraffice.tx = 0
        report.currentTraffice.rx = 0
        report.totalTraffice.addRx(x: Int(report.lastTraffice.rx))
        report.totalTraffice.addTx(x: Int(report.lastTraffice.tx))
        
        report.updateMax()
    }
}
