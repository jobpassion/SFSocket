//
//  UDPReplayer.swift
//  Surf
//
//  Created by 孔祥波 on 16/5/18.
//  Copyright © 2016年 yarshure. All rights reserved.
//

import Foundation
// UDP 直接转发器
import AxLogger
import DarwinCore
import CocoaAsyncSocket
class SFUDPForwarder:SFUDPConnector, GCDAsyncUdpSocketDelegate {
    
 
    
    var socket:GCDAsyncUdpSocket?
    var targetHost:String = "" //cache dest ip
    //var targetPort:UInt16 = 0
    
    
    var rule:SFRuler?
    
    override init(sip:Data, dip:Data,packet:UDPPacket) {
        super.init(sip: sip , dip: dip , packet: packet)
        //targetHost =
        //AxLogger.log("current only udp port 53 process, other port packet drop",level:.Warning)
        
        
        //socket = GCDAsyncUdpSocket.init(delegate: self, delegateQueue: dispatchQueue)
        //let rec:GCDAsyncUdpSocketReceiveFilterBlock = (NSData!, NSData!, AutoreleasingUnsafeMutablePointer<AnyObject?>) {
        
        //}
        targetHost = datatoIP(dip)
        start()
        
    }
    func start() {
        
        socket = GCDAsyncUdpSocket.init(delegate: self, delegateQueue: SFTCPConnectionManager.manager.dispatchQueue)
        
        do {
            //try socket?.connectToHost("192.168.11.1", onPort: 53)
            socket?.setDelegate(self)
            socket?.setDelegateQueue(SFTCPConnectionManager.manager.dispatchQueue)
            
            let message = String.init(format: "start udp %@:%d", targetHost ,dstPort)
            AxLogger.log(message,level: .Trace)
            try socket?.connect(toHost: targetHost, onPort: dstPort)
            
        } catch let e as NSError {
            //AxLogger.log("can't connectToHost \(server)",level: .Erro)
            //NSLog("DNS can't connectToHost \(server) \(port) error:\(e)")
            AxLogger.log("DNS can't connectToHost \(e.description) ",level: .Error)
        }
    }
    func udpSocket(_ sock: GCDAsyncUdpSocket, didConnectToAddress address: Data) {
        
        do {
            try sock.beginReceiving()
            connected = true
            processQuery()
        }catch let e as NSError {
            AxLogger.log("DNS:\(reqID) beginReceiving error :\(e.localizedDescription) ", level: .Error)
        }
        
    }
    override func addQuery(packet udp:UDPPacket!) {
        //let ip = IPv4Packet(PacketData:data)
        //let udp = UDPPacket.init(PacketData: ip.payloadData())
        sendingQueue.append(udp)
        
        
//        if  dstPort != 53 {
//            //AxLogger.log("dst \(dstPort) udp packet  drop")
//            if dstPort >= 16384 &&  dstPort <= 16386{
//                //AxLogger.log("Apple use udp  \(dstPort) Apple FaceTime, Apple Game Center (RTP/RTCP) http://www.speedguide.net/port.php?port=16386")
//            }
//            self.delegate!.serverDidClose(self)
//            return
//        }
        //let packet:DNSPacket = DNSPacket.init(data: udp.payloadData())
        //clientAddress = 0xf0070109.bigEndian// ip.srcIP
        // NSLog("DNS queryDomains:\(packet.queryDomains) via \(SFNetworkInterfaceManager.instances.dnsAddress())")
        // dstAddress = ip.destinationIP
        
        //let inden = packet.identifier
        //waittingQueriesMap[Int(queryIDCounter)] = inden
        //waittingQueriesTimeMap[inden] = NSDate()
        //AxLogger.log("inden:\(inden) clientPort:\(clientPort)",level: .Debug)
        //AxLogger.log("\(packet.queryDomains),waittingQueriesMap \(waittingQueriesMap)",level: .Debug)
        //let packet:DNSPacket = DNSPacket.init(packetData: data)
        
        //queries.append(packet!.rawData)
        processQuery()
        
    }
    
    func processQuery() {
        
//        //AxLogger.log("\(packet.rawData)")
//        
//        if (queryIDCounter == UInt16(UINT16_MAX)) {
//            queryIDCounter = 0
//        }
//        queryIDCounter += 1
        
     
        //let  queryID:UInt16 = queryIDCounter++;
        //data.replaceBytesInRange(NSMakeRange(0, 2), withBytes: queryID)
        
        //[data replaceBytesInRange:NSMakeRange(0, 2) withBytes:&queryID];
        //how to send data
        //waittingQueriesMap[queryID] = data
        //socket?.sendData(data, toHost: "192.168.0.245", port: 53, withTimeout: 10, tag: 0)
        //AxLogger.log("send dns request data: \(packet.rawData)",level: .Trace)
        
        activeTime = Date() as Date
        let udp:UDPPacket = sendingQueue.removeFirst()
        //let clientPort = udp.sourcePort
        _ = udp.destinationPort
        if let s = socket {
            SFTCPConnectionManager.manager.socketQueue.async(execute: { 
                s.send(udp.payloadData() as Data, withTimeout: 10, tag: 0)
            })
            
        }
        
    }
    internal func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive tempdata: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        //收到dns replay packet
        activeTime = Date() as Date
        AxLogger.log("UDP-\(reqID) recv data len:\(tempdata.length)", level: .Trace)
        var r:Range<Data.Index>
        if address.count == 4{
            r = Range(0 ..< 4)
        }else {
            //10020035 c0a800f5 00000000 00000000 这个是ipv6?
            //addr = address.subdataWithRange(NSMakeRange(4, 4))
            r = Range(4 ..< 8)
        }
        
        var srcip:UInt32 = 0//0xc0a800f5//0b01 // 00f5
        //var dstip:UInt32 =  0xf0070109 //bigEndian//= 0xc0a80202
        //if let c = clientAddress {
        //c.getBytes(&dstip, length: 4)
        let buffer = UnsafeMutableBufferPointer(start: &srcip, count: 1)
        _ = address.copyBytes(to: buffer , from: r)
        
        //}
        
        let data:Data = tempdata
        
        
        //AxLogger.log("\(data) from address \(address.subdataWithRange(r))",level: .Trace)
        let data_len = 1460 - 28 //ip header + udp header
        if data.count != 0 {
            //NSLog("udpSocket recv data:%@", data)
            if data.count > data_len {
                var used:Int = 0
                let total:Int = data.count
                while used < total {
                    var buffer:Data
                    if total - used > data_len {
                        buffer = data.subdata(in: Range(used ..< used + data_len))
                        used += data_len
                    }else {
                        buffer = data.subdata(in: Range(used ..< total ))
                        used += total - used
                    }
                    writePacketData(buffer)
                }
            }else {
                 writePacketData(data)
            }
           
            
        }else {
            AxLogger.log("DNS request data error!",level: .Error)
            self.delegate!.serverDidClose(self)
        }
        
    }
    internal func writePacketData(_ data:Data){
        //这里要修改
        //NSLog("dns packet %@", data)
        
        let  srcip:UInt32 = inet_addr(targetHost.cString(using: String.Encoding.utf8)!) //0xc0a800f5//0b01 // 00f5
        let dstip:UInt32 = inet_addr("240.7.1.9".cString(using: String.Encoding.utf8))//= 0xc0a80202
        
        let length = 20 + data.count + 8
        let h = ipHeader(Int32(length), srcip ,dstip,queryIDCounter.bigEndian,UInt8(IPPROTO_UDP)) as Data
        queryIDCounter += 1
        
        //NSLog("DNS 111")
        
//        var udp:UDPPacket
//        var ip:IPv4Packet
//        var  packet:DNSPacket
//        if let cacheData = cacheData {
//            
//            cacheData.appendData(data)
//            packet = DNSPacket.init(data: cacheData)
//        }else {
//            packet = DNSPacket.init(data: data)
//        }
        //NSLog("DNS 222")
    
        let  d = SFData()
        d.append(h)
        
        let sport:UInt16 = dstPort
        d.append(sport.bigEndian)
        let cPort = clientPort //  waittingQueriesMap[inden]{
        d.append(UInt16((cPort.bigEndian)))
        
        let ulen = data.count + 8
        d.append(UInt16(ulen).bigEndian)
        d.append(UInt16(0))
        //        d.appendBytes(&(a.bigEndian), length: sizeof(a))
        //        d.appendBytes(&(srcport?.bigEndian) ,length: 2)
        d.append(data)
        //waittingQueriesMap.removeValueForKey(inden)
        if let delegate = self.delegate {
            delegate.serverDidQuery(self, data: d.data,close:  false)
        }
    }
     func udpSocket(_ sock: GCDAsyncUdpSocket, didNotConnect error: Error?){
        //NSLog("DNS didNotConnect: \(error)")
//        if let p = proxy {
//            let message = String.init(format: "#### %@:%d didNotConnect", p.serverAddress,p.serverPort)
//            AxLogger.log(message,level: .Error)
//            p.udpRelay = false
//            AxLogger.log("####  \(p.serverAddress):\(p.serverPort) UDP RELAY Error",level: .Warning)
//        }
        DispatchQueue.main.async { 
            if let d  = self.delegate {
                d.serverDidClose(self)
            }
        }
        
        
        
        
    }
    func udpSocket(_ sock: GCDAsyncUdpSocket, didSendDataWithTag tag: Int){
        //NSLog("DNS didSendDataWithTag")
    }
    func udpSocketDidClose(_ sock: GCDAsyncUdpSocket, withError error: Error?){
        //NSLog("DNS udpSocketDidClose \(error)")
        //socket?.setDelegate( nil)
        
        //socket = nil
        //self.start()
        if let d = delegate {
            d.serverDidClose(self)
        }
        
    }
    internal func udpSocket(_ sock: GCDAsyncUdpSocket, didNotSendDataWithTag tag: Int, dueToError error: Error?){
        //NSLog("DNS didNotSendDataWithTag \(error)")
        // self.delegate!.serverDidClose(self)
        if let d = delegate {
            d.serverDidClose(self)
        }
    }
    func shutdownSocket(){
        //maybe crash
        if let s = socket {
            s.setDelegate(nil)
            s.setDelegateQueue(nil)
            s.close()
        }
    }
    deinit {
        
        if let s = socket {
            s.setDelegate( nil)
            
            //s = nil
        }
        AxLogger.log("DNS-Server deinit",level: .Debug)
    }
    
}
