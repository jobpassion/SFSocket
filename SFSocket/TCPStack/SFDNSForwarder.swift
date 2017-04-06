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

import AxLogger
//
//let dispatchQueue = dispatch_queue_create("DNSServer", nil);
//let socketQueue = dispatch_queue_create("com.abigt.socket.dns", nil);
open  class SFDNSForwarder:SFUDPConnector, GCDAsyncUdpSocketDelegate{
    
//    var decrypt_ctx:SEContextRef =  SEContextRef.alloc(1)//enc_ctx_create()//
//    var encrypt_ctx:SEContextRef =  SEContextRef.alloc(1)//enc_ctx_create()//SEContextRef.alloc(1)
//    let sbuf:bufferRef = bufferRef.alloc(1)
//    let rbuf:bufferRef = bufferRef.alloc(1)
    
    var domains:[String] = []
    
    //var packet:DNSPacket?
    var socket:GCDAsyncUdpSocket?
    var waittingQueriesMap:[Int:UInt16] = [:]// iden:port
    //var queries:[DNSPacket] = []
    //var queryIDCounter:UInt16 = 0
    var targetHost:String = ""
    let targetPort:UInt16 = 53
    
    var proxy:SFProxy!
    var startTime:Date = Date()
    var dnsSetting:DNSServer?
    var cacheData:Data?
    override init(sip: Data, dip: Data, packet: UDPPacket) {
        
        //targetHost = server
        super.init(sip: sip, dip: dip, packet: packet)
        
         start()
    }
    func config() -> Bool{
        
        //        decrypt_ctx = enc_ctx_create()
        //        encrypt_ctx = enc_ctx_create()
        if let p = ProxyGroupSettings.share.findProxy("Proxy") {
            if p.type == .SS && p.udpRelay {
                proxy = p
                let m = 0// settingSS(proxy!.password,method: proxy!.method)
                if m == -1 {
                    return false
                }
//                enc_ctx_init(m, encrypt_ctx, 1);
//                enc_ctx_init(m, decrypt_ctx, 0);
//                
//                balloc(sbuf,Int(TCP_CLIENT_SOCKS_RECV_BUF_SIZE_UInt))
//                balloc(rbuf,Int(TCP_CLIENT_SOCKS_RECV_BUF_SIZE_UInt))
                
                return true

            }
            

        }
        
        //        if targetHost.characters.count > 0 {
        //            buildHead()
        //        }
        
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
            //AxLogger.log("\(ccIdString) target host use ip \(targetHost) ",level: .Debug)
            let i :UInt32 = inet_addr(targetHost.cString(using: .utf8)!)
            header.append(i)
            header.append(targetPort.byteSwapped)
            addr_len  +=  MemoryLayout<UInt32>.size + 2
            
        }else if request_atyp == .DOMAIN{
            
            header.append(SOCKS_DOMAIN)
            addr_len += 1
            let name_len = targetHost.characters.count
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
                
                
                //AxLogger.log("\(ccIdString) convert \(targetHost) to Data:\(data)",level: .Info)
                header.append(data)
                header.append(targetPort.byteSwapped)
            }else {
                //AxLogger.log("\(ccIdString) convert \(targetHost) to in6_addr error )",level: .Warning)
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
        if !targetHost.isEmpty && targetHost != SKit.env.proxyIpAddr{
            dnsSetting =  DNSServer.init(ip:targetHost,sys:true)
        }else{
            dnsSetting = SFDNSManager.manager.giveMeAserver()
        }
        guard let dnsSetting = dnsSetting else {return}
        AxLogger.log("\(cIdString) use dns server:\(dnsSetting.ipaddr)",level: .Debug)
        socket = GCDAsyncUdpSocket.init(delegate: self, delegateQueue: SFTCPConnectionManager.manager.dispatchQueue)
        let port:UInt16 = 53
        do {
            //try socket?.connectToHost("192.168.11.1", onPort: 53)
            socket?.setDelegate(self)
            socket?.setDelegateQueue(SFTCPConnectionManager.manager.dispatchQueue)
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
            AxLogger.log("\(cIdString) DNS can't connectToHost \(dnsSetting.ipaddr) \(e)",level: .Error)
        }
    }
    override func addQuery(packet udp:UDPPacket!) {
        //let ip = IPv4Packet(PacketData:data)
        //let udp = UDPPacket.init(PacketData: ip.payloadData())
        //en queue
        sendingQueue.append(udp)
        if connected {
            processQuery()
        }else {
            AxLogger.log("\(cIdString) UDP:\(reqID) not connected packet en queue",level: .Error)
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
        
        AxLogger.log("\(cIdString) DNS queryDomains:\(packet.queryDomains) ",level:.Verbose)
        // dstAddress = ip.destinationIP
        
        let inden = packet.identifier
        waittingQueriesMap[Int(queryIDCounter)] = inden
        //waittingQueriesTimeMap[inden] = Date()
        //AxLogger.log("inden:\(inden) clientPort:\(clientPort)",level: .Debug)
        //AxLogger.log("\(packet.queryDomains),waittingQueriesMap \(waittingQueriesMap)",level: .Debug)
        //let packet:DNSPacket = DNSPacket.init(packetData: data)
        //crash there
        //queries.append(packet)
        
        
        //AxLogger.log("\(packet.rawData)")
        AxLogger.log("\(cIdString) DNSFORWARDER now send query \(packet.queryDomains.first!)",level: .Verbose)
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
                AxLogger.log("\(cIdString) req:\(packet.rawData)",level: .Error)
            }
            
            
        }
        
        //let  queryID:UInt16 = queryIDCounter++;
        //data.replaceBytesInRange(NSMakeRange(0, 2), withBytes: queryID)
        
        //[data replaceBytesInRange:NSMakeRange(0, 2) withBytes:&queryID];
        //how to send data
        //waittingQueriesMap[queryID] = data
        //socket?.sendData(data, toHost: "192.168.0.245", port: 53, withTimeout: 10, tag: 0)
       //AxLogger.log("send dns request data: \(packet.rawData)",level: .Trace)
        
        activeTime = Date()
        if let _ = proxy {
//            let temp = NSMutableData()
//            let head = buildHead()
//            temp.appendData(head)
//            temp.appendData(packet.rawData)
//            brealloc(sbuf,temp.length,CLIENT_SOCKS_RECV_BUF_SIZE)
//            buffer_t_copy(sbuf,UnsafePointer(temp.bytes),temp.length)
//            var  len = buffer_t_len(sbuf)
//            let ret = ss_encrypt(sbuf,encrypt_ctx,len)
//            if ret != 0 {
//                //abort()
//                //AxLogger.log("\(cccIdString) ss_encrypt error ",level: .Error)
//            }
//            len = buffer_t_len(sbuf)
//            let result = NSData.init(bytes: buffer_t_buffer(sbuf), length: len)
//
//            if let s = socket {
//                s.sendData(result, withTimeout: 0.5, tag: Int(packet.identifier))
//            }
        }else {
            if let s = socket {
                startTime = Date()
                let socketQ = SFTCPConnectionManager.manager.socketQueue
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
            AxLogger.log("\(cIdString) start recv", level: .Trace)
        }catch let e as NSError {
            AxLogger.log("\(cIdString) beginReceiving error :\(e.localizedDescription) ", level: .Error)
        }
        connected = true
        processQuery()
        
    }
    open func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive tempdata: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        //收到dns replay packet
        activeTime = Date()
       //AxLogger.log("\(cIdString) recv:\(tempdata as NSData)", level: .Debug)
        var r:Range<Data.Index>
        if address.count == 4{
            r = Range(0..<4)
        }else {
            //10020035 c0a800f5 00000000 00000000 这个是ipv6?
            //addr = address.subdataWithRange(NSMakeRange(4, 4))
            r = Range(4 ..<  4 + 4)
        }
        
        var srcip:UInt32 = 0//0xc0a800f5//0b01 // 00f5
        //var dstip:UInt32 = 0xf0070109 //bigEndian//= 0xc0a80202
        //if let c = clientAddress {
            //c.getBytes(&dstip, length: 4)
        //    address.copyBytes(to: &UInt8(srcip), from: r)
        let buffer = UnsafeMutableBufferPointer(start: &srcip, count: 1)
        _ = address.copyBytes(to: buffer , from: r)
        //}
        
        var data:Data?
        if let p = proxy {
//            buffer_t_copy(rbuf,UnsafePointer(tempdata.bytes),tempdata.length)
//            let ret = ss_decrypt(rbuf, decrypt_ctx,tempdata.length)
//            //let x = tag+1
//            if ret != 0  {
//                //AxLogger.log("\(ccIdString) ss_decrypt error ",level: .Error)
//                //self.readDataWithTimeout(0.1, length: 2048, tag: x)
//                logStream.write("DNS decrypt error!")
//            }else {
//                let len = buffer_t_len(rbuf)
//                let result  = NSData.init(bytes: buffer_t_buffer(rbuf), length: len)
//                //AxLogger.log("\(ccIdString) decrypt \(out)",level: .Debug)
//                //let type:SOCKS5HostType = .IPV4
//                data = result.subdataWithRange(NSMakeRange(7, result.length-7))
//            }
            AxLogger.log("\(p.serverAddress)",level: .Trace)
            //NSLog("dns packet 333")
        }else {
            
            data = tempdata
        }
        
       //AxLogger.log("\(data) from address \(address.subdataWithRange(r))",level: .Trace)
        if let data = data {
            //NSLog("udpSocket recv data:%@", data)
            writeDNSPacketData(data,cache: true)

        }else {
            AxLogger.log("DNS request error!",level: .Error)
            self.delegate!.serverDidClose(self)
        }
        
    }
     func writeDNSPacketData(_ data:Data,cache:Bool){
        //NSLog("dns packet %@", data)
        
        let  srcip:UInt32 = inet_addr(SKit.env.proxyIpAddr.cString(using: String.Encoding.utf8)!) //0xc0a800f5//0b01 // 00f5
        let dstip:UInt32 = inet_addr(SKit.env.tunIP.cString(using: String.Encoding.utf8)!)//= 0xc0a80202
        
        let h = ipHeader(20+data.count+8, srcip ,dstip,queryIDCounter.bigEndian,UInt8(IPPROTO_UDP))
        queryIDCounter += 1
        //NSLog("DNS 111")
        //AxLogger.log("\(cIdString) IPHeader \(h! as NSData)", level: .Debug)
        var  packet:DNSPacket
        if var cacheData = cacheData {
            
            cacheData.append(data)
            packet = DNSPacket.init(data: cacheData)
        }else {
            packet = DNSPacket.init(data: data)
        }
        //NSLog("DNS 222")
        let inden = packet.identifier
        if packet.finished == false {
            if var c = cacheData {
                c.append(data)
            }else {
                cacheData = Data()
                cacheData?.append(data)
            }
            
        }else {
            AxLogger.log("DNSFORWARDER  \(packet.queryDomains.first!) Finished",level: .Debug)
//            if let rData = waittingQueriesTimeMap[inden]{
//                waittingQueriesTimeMap.removeValue(forKey: inden)
//                let now = Date()
//                let second = now.timeIntervalSince(rData)
//                // debugLog("DNS Response Fin" + packet.queryDomains.first!)
//                let message = String.init(format:"DNS Response Fin %@ use %.2f second",packet.queryDomains.first!, second)
//                AxLogger.log(message,level: .Trace)
//            }
            
            //NSLog("DNS %@",packet.queryDomains)
            //AxLogger.log("domains answer:\(packet.queryDomains) iden :\(inden) clientPort:\(cPort) use second:\(second)",level: .Debug)
            //        waittingQueriesTimeMap.removeValueForKey(inden)
            waittingQueriesMap.removeValue(forKey: Int(inden))
            cacheData?.count = 0
            
           // NSLog("DNS Response Fin %@", packet.queryDomains.first!,packet.answerDomains)
           
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
        //        d.appendBytes(&(a.bigEndian), length: sizeof(a))
        //        d.appendBytes(&(srcport?.bigEndian) ,length: 2)
        d.append(data)
        //AxLogger.log("\(cIdString) buffer:\(d.data as NSData)", level: .Debug)
        //waittingQueriesMap.removeValueForKey(inden)
        if let delegate = self.delegate {
            AxLogger.log("\(cIdString) IPPacket write to tune\(d.description)", level: .Debug)
            delegate.serverDidQuery(self, data: d.data,close:  packet.finished)
        }
    }
    open func udpSocket(_ sock: GCDAsyncUdpSocket, didNotConnect error: Error?){
        if let error = error {
            AxLogger.log("DNS didNotConnect: \(error.localizedDescription)",level:.Error)
        }
        
        if let p = proxy {
            let message = String.init(format: "#### %@:%d didNotConnect", p.serverAddress,p.serverPort)
            
            p.udpRelay = false
            AxLogger.log("#### \(cIdString)  \(p.serverAddress):\(p.serverPort) UDP RELAY Error \(message)",level: .Error)
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
        AxLogger.log("DNS didSendDataWithTag", level: .Info)
    }
    open func udpSocketDidClose(_ sock: GCDAsyncUdpSocket, withError error: Error?){
        if let error = error {
            AxLogger.log("DNS udpSocketDidClose \(error.localizedDescription)",level: .Error)
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
    func shutdownSocket(){
        //maybe crash
        if let s = socket {
            s.setDelegate(nil)
            s.setDelegateQueue(nil)
            s.close()
        }
    }
    deinit {
        if let _ = proxy {
//            bfree(sbuf)
//            sbuf.dealloc(1)
//            bfree(rbuf)
//            rbuf.dealloc(1)
//            free_enc_ctx(encrypt_ctx)
//            free_enc_ctx(decrypt_ctx)
        }
        if let s = socket {
            s.setDelegate( nil)
            
            //s = nil
        }
        AxLogger.log("DNS-Server deinit",level: .Debug)
    }
    
}
