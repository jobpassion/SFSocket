 //
//  DNSServer.swift
//  SimpleTunnel
//
//  Created by 孔祥波 on 15/10/26.
//  Copyright © 2015年 Apple Inc. All rights reserved.
//

import Foundation
import DarwinCore
import Darwin
import NetworkExtension
import CocoaAsyncSocket
import Xcon
import AxLogger
import XFoundation
import XProxy
open  class SFDNSForwarder:SFUDPConnector, GCDAsyncUdpSocketDelegate{
    
//    var decrypt_ctx:SEContextRef =  SEContextRef.alloc(1)//enc_ctx_create()//
//    var encrypt_ctx:SEContextRef =  SEContextRef.alloc(1)//enc_ctx_create()//SEContextRef.alloc(1)
//    let sbuf:bufferRef = bufferRef.alloc(1)
//    let rbuf:bufferRef = bufferRef.alloc(1)
    
    var domains:[String] = []
    
    //var packet:DNSPacket?
    
    var socketN:GCDAsyncUdpSocket?
    var waittingQueriesMap:[Int:UInt16] = [:]// iden:port
    //var queries:[DNSPacket] = []
    //var queryIDCounter:UInt16 = 0
    var targetHost:String = ""
    let targetPort:UInt16 = 53
    
    var proxy:SFProxy!
    var startTime:Date = Date()
    
    var dnsSetting:DNSServer?
    var cacheData:Data?
    override public init(sip: Data, dip: Data, packet: UDPPacket) {
        
        //targetHost = server
        super.init(sip: sip, dip: dip, packet: packet)
        
         start()
    }
    func config() -> Bool{
        return false
    }

    func buildHead() ->Data {
        let header = SFData()
        //NSLog("TCPSS %@:%d",targetHost,targetPort)
        //targetHost is ip or domain
        var addr_len = 0
        
        //        let  buf:bufferRef = bufferRef.alloc(1)
        //        balloc(buf,BUF_SIZE)
        let  request_atyp:SOCKS5HostType = targetHost.validateIpAddr()
        if  request_atyp  == .IPV4{
            header.append(SOCKS_IPV4)
            //header.write(to: SOCKS_IPV4)
             addr_len += 1
            //SKit.log("\(ccIdString) target host use ip \(targetHost) ",level: .Debug)
            let i :UInt32 = inet_addr(targetHost.cString(using: .utf8)!)
            header.append(i)
            header.append(targetPort.byteSwapped)
            addr_len  +=  MemoryLayout<UInt32>.size + 2
            
        }else if request_atyp == .DOMAIN{
            
            header.append(SOCKS_DOMAIN)
            addr_len += 1
            let name_len = targetHost.count
            header.append(UInt8(name_len))
            addr_len += 1
            header.append(targetHost.data(using: .utf8)!)
            addr_len += name_len
            header.append(targetPort.byteSwapped)
            addr_len += 2
        }else {
            //ipv6
            header.append(SOCKS_IPV6)
            addr_len += 1
            if let data =  toIPv6Addr(ipString: targetHost) {
                
                
                //SKit.log("\(ccIdString) convert \(targetHost) to Data:\(data)",level: .Info)
                header.append(data)
                header.append(targetPort.byteSwapped)
            }else {
                //SKit.log("\(ccIdString) convert \(targetHost) to in6_addr error )",level: .Warning)
                //return
            }
            //2001:0b28:f23f:f005:0000:0000:0000:000a
            //            let ptr:UnsafePointer<Int8> = UnsafePointer<Int8>.init(bitPattern: 32)
            //            let host:UnsafeMutablePointer<Int8> = UnsafeMutablePointer.init(targetHost.cStringUsingEncoding(NSUTF8StringEncoding)!)
            //            inet_pton(AF_INET6,ptr,host)
        }
        return header.data
    }

    func start() {
        
        //SFNetworkInterfaceManager.instances.updateInfo()
        if !targetHost.isEmpty && targetHost != SKit.proxyIpAddr{
            dnsSetting =  DNSServer.init(ip:targetHost,sys:true)
        }else{
            dnsSetting = SFDNSManager.manager.giveMeAserver(system: true)
        }
        guard let dnsSetting = dnsSetting else {return}
        SKit.log("\(cIdString) use dns server:\(dnsSetting.ipaddr)",level: .Debug)
        socket = GCDAsyncUdpSocket.init(delegate: self, delegateQueue: SFTCPConnectionManager.shared.dispatchQueue)
        let port:UInt16 = 53
        do {
            
            if config() {
                
                if let proxy = proxy {
                    if proxy.udpRelay {
                        //server = proxy.serverAddress
                        //port = UInt16(proxy.serverPort)!
                    }
                }
            }
           // let message = String.init(format: "DNS START UDP %@:%d", server ,port)
            //debugLog(message)
            try socket?.connect(toHost: dnsSetting.ipaddr, onPort: port)
            
        } catch let e as NSError {
            SKit.log("\(cIdString) DNS can't connectToHost \(dnsSetting.ipaddr) \(e)",level: .Error)
        }
    }
    override public func addQuery(packet udp:UDPPacket!) {
        //let ip = IPv4Packet(PacketData:data)
        //let udp = UDPPacket.init(PacketData: ip.payloadData())
        //en queue
        sendingQueue.append(udp)
        if connected {
            processQuery()
        }else {
            SKit.log("\(cIdString) UDP:\(reqID) not connected packet en queue",level: .Error)
        }
        
    }
   
    func processQuery() {
        if sendingQueue.isEmpty {
            return
        }
        let udp:UDPPacket = sendingQueue.removeFirst()
        clientPort = udp.sourcePort
        
        
        
        
        let packet:DNSPacket = DNSPacket.init(data: udp.payloadData())
        //clientAddress = 0xf0070109.bigEndian// ip.srcIP
        
        SKit.log("\(cIdString) DNS queryDomains:\(packet.queryDomains) ",level:.Verbose)
        // dstAddress = ip.destinationIP
        
        let inden = packet.identifier
        waittingQueriesMap[Int(queryIDCounter)] = inden
      
        SKit.log("\(cIdString) DNSFORWARDER now send query \(packet.queryDomains.first!)",level: .Verbose)
        if (queryIDCounter == UInt16(UINT16_MAX)) {
            queryIDCounter = 0
        }
        queryIDCounter += 1
        
        if let domain = packet.queryDomains.first {
            if !domain.isEmpty {
                
                
                
                if let cache = packet.findCache() {
                    
                    writeDNSPacketData(cache,cache: false)
                    return
                }
            }else {
                SKit.log("\(cIdString) req:\(packet.rawData)",level: .Error)
            }
            
            
        }
        
        activeTime = Date()
        if let _ = proxy {

        }else {
            if let s = socket {
                startTime = Date()
                let socketQ = SFTCPConnectionManager.shared.socketQueue
                socketQ.async(execute: { 
                     s.send(packet.rawData, withTimeout: 0.5, tag: Int(packet.identifier))
                })
                
                
            }
            
            
        }
        
        
    }
    var cIdString:String{
        return "UDP-DNS:\(reqID)"
    }
    open func udpSocket(_ sock: GCDAsyncUdpSocket, didConnectToAddress address: Data) {
        do {
            try sock.beginReceiving()
            SKit.log("\(cIdString) start recv", level: .Trace)
        }catch let e as NSError {
            SKit.log("\(cIdString) beginReceiving error :\(e.localizedDescription) ", level: .Error)
        }
        connected = true
        processQuery()
        
    }
    open func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive tempdata: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        //收到dns replay packet
        activeTime = Date()
       //SKit.log("\(cIdString) recv:\(tempdata as NSData)", level: .Debug)
        var r:Range<Data.Index>
        if address.count == 4{
            r = 0..<4
        }else {
            //10020035 c0a800f5 00000000 00000000 这个是ipv6?
            //addr = address.subdataWithRange(NSMakeRange(4, 4))
            r = 4 ..<  4 + 4
        }
        
        var srcip:UInt32 = 0//0xc0a800f5//0b01 // 00f5
      
        let buffer = UnsafeMutableBufferPointer(start: &srcip, count: 1)
        _ = address.copyBytes(to: buffer , from: r)
       
        
        var data:Data?
        if let p = proxy {

            SKit.log("\(p.serverAddress)",level: .Trace)
            //NSLog("dns packet 333")
        }else {
            
            data = tempdata
        }
        
       //SKit.log("\(data) from address \(address.subdataWithRange(r))",level: .Trace)
        if let data = data {
            //NSLog("udpSocket recv data:%@", data)
            writeDNSPacketData(data,cache: true)

        }else {
            SKit.log("DNS request error!",level: .Error)
            self.delegate!.serverDidClose(self)
        }
        
    }
     func writeDNSPacketData(_ data:Data,cache:Bool){
        //NSLog("dns packet %@", data)
        
        let  srcip:UInt32 = inet_addr(SKit.proxyIpAddr.cString(using: String.Encoding.utf8)!) //0xc0a800f5//0b01 // 00f5
        let dstip:UInt32 = inet_addr(SKit.tunIP.cString(using: String.Encoding.utf8)!)//= 0xc0a80202
        let length:Int = 28
        let h = ipHeader(Int32(data.count + length), srcip ,dstip,queryIDCounter.bigEndian,UInt8(IPPROTO_UDP))
        queryIDCounter += 1
        //NSLog("DNS 111")
        //SKit.log("\(cIdString) IPHeader \(h! as NSData)", level: .Debug)
        var  packet:DNSPacket
        if var cacheData = cacheData {
            
            cacheData.append(data)
            packet = DNSPacket.init(data: cacheData)
        }else {
            packet = DNSPacket.init(data: data)
            if var c = cacheData {
                c.append(data)
            }else {
                cacheData = Data()
                cacheData?.append(data)
            }
        }
  
        let inden = packet.identifier
    
        if packet.finished {
            SKit.log("DNSFORWARDER  \(packet.queryDomains.first!) Finished",level: .Debug)
            
            waittingQueriesMap.removeValue(forKey: Int(inden))
            cacheData?.count = 0
            write(packet: packet)
        }
        let d = SFData()
        d.append(h!)
        //可能经过代理
        let sport:UInt16 = 53
        d.append(sport.bigEndian)
        let cPort = clientPort //  waittingQueriesMap[inden]{
        d.append(UInt16((cPort.bigEndian)))
        
        let ulen = data.count + 8
        d.append(UInt16(ulen).bigEndian)
        d.append(UInt16(0))
     
        d.append(data)

        if let delegate = self.delegate {
            SKit.log("\(cIdString) IPPacket write to tune\(d.description)", level: .Debug)
            delegate.serverDidQuery(self, data: d.data,close:  packet.finished)
        }else {
            shutdownSocket()
        }
    }
    open func udpSocket(_ sock: GCDAsyncUdpSocket, didNotConnect error: Error?){
        if let error = error {
            SKit.log("DNS didNotConnect: \(error.localizedDescription)",level:.Error)
        }
        
        if let p = proxy {
            let message = String.init(format: "#### %@:%d didNotConnect", p.serverAddress,p.serverPort)
            
            p.udpRelay = false
            SKit.log("#### \(cIdString)  \(p.serverAddress):\(p.serverPort) UDP RELAY Error \(message)",level: .Error)
        }
           let q = DispatchQueue.main
           q.async { 
            if let d  = self.delegate {
                d.serverDidClose(self)
            }

        }
        
       
    }
    open func udpSocket(_ sock: GCDAsyncUdpSocket, didSendDataWithTag tag: Int){
       //NSLog("DNS didSendDataWithTag")
        SKit.log("DNS didSendDataWithTag", level: .Info)
    }
    open func udpSocketDidClose(_ sock: GCDAsyncUdpSocket, withError error: Error?){
        if let error = error {
            SKit.log("DNS udpSocketDidClose \(error.localizedDescription)",level: .Error)
        }
        
        //socket?.setDelegate( nil)
        
        //socket = nil
        //self.start()
        if let d = delegate {
            d.serverDidClose(self)
        }
        
    }
    open func udpSocket(_ sock: GCDAsyncUdpSocket, didNotSendDataWithTag tag: Int, dueToError error: Error?){
       //NSLog("DNS didNotSendDataWithTag \(error)")
        // self.delegate!.serverDidClose(self)
        if let d = delegate {
            d.serverDidClose(self)
        }
    }
    
    deinit {
        
        if let s = socket {
            s.setDelegate( nil)
        }
        SKit.log("DNS-Server deinit",level: .Debug)
    }
    
}
extension SFDNSForwarder {
    func write(packet:DNSPacket)  {
        let req = SFRequestInfo.init(rID: UInt(reqID))
        req.url = packet.queryDomains.first!
        req.mode = .DNS
        let x = packet.ipString.map { $0 + "\r\n" }
        
        var str:String = "DNS/1.1 200 OK\r\n"
        for (idx,yy) in x.enumerated(){
            str += "IP\(idx): "
            str += yy
        }
        str += "\r\n\r\n"
        req.respHeader = SFHTTPResponseHeader.init(data: str.data(using: .utf8)!)
        //MARK: GRDB issue
//        RequestHelper.shared.saveReqInfo(req)
    }
}
