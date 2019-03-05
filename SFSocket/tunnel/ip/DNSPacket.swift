//
//  DNSPacket.swift
//  Surf
//
//  Created by yarshure on 15/12/24.
//  Copyright © 2015年 yarshure. All rights reserved.
//

import Foundation
import Darwin
import AxLogger
import XRuler
import XFoundation
public enum QTYPE:UInt16,CustomStringConvertible{
    case a = 0x0001
    case ns = 0x0002
    case cname = 0x005
    case soa = 0x0006
    
    case wks = 0x000B
    case ptr = 0x000C
    case mx = 0x000F
    case srv = 0x0021
    
    case a6 = 0x001C
    case any = 0x00FF
    
    
    public var description: String {
        switch self {
        case .a: return  "A"
        case .ns : return "NS"
        case .cname : return "CNAME"
        case .soa : return "SOA"
            
        case .wks : return "WKS"
        case .ptr : return "PTR"
        case .mx : return "MX"
        case .srv : return "SRV"
            
        case .a6 : return  "AAAA"
        case .any : return "ANY"
        }
    }
}


class DNSPacket: NSObject {
    var identifier:UInt16 = 0
    var queryDomains:[String] = []
    var answerDomains:[String:String] = [:]
    var rawData:Data
    var qr:CChar = 0
    var count:UInt16 = 0
    var qType:UInt16 = 0
    var qClass:UInt16 = 0
    var reqCount:UInt16 = 0
    var answerCount:UInt16 = 0
    var ipString:[String] = []
    var finished:Bool = true
    //    override init() {
    //
    //    }
    
    
    override var description: String{
        get {
            if ipString.count != 0 {
                let  initialResult = ""
                return ipString.reduce(initialResult) { (t,e )  in
                    if t.count == 0 {
                        return e
                    }else {
                        return t + "," + e
                    }
                    
                }
                
            }else {
                return queryDomains.first!
            }
        }
    }
    var useCache:Bool{
        get {
            if qType == 0x1 {
                return true
            }else {
                return false
            }
        }
    }
    func findCache() ->Data?{
        if useCache == false {
            return nil
        }else {
            //去点操作
            let domain = queryDomains.first!
            let d = domain.delLastN(1)
            var ip:[String] = []
            if let x = SFSettingModule.setting.queryDomain(d), !x.isEmpty {
                
                ip.append(x)
            }else {
                let  x = SFSettingModule.setting.searchDomain(domain)
                if !x.isEmpty {
                    ip.append(contentsOf: x)
                    
                    
                }
            }
            
            
            if !ip.isEmpty {
                
                let respData = DNSPacket.genPacketData(ip, domain: d, identifier: identifier)
                
                return respData
            }
        }
        return nil
    }
    init(data:Data) {
        if data.count < 12 {
            
            AxLogger.log("DNS data error data",level: .Error)
        }
        
        rawData = data
        super.init()
        var bytes:UnsafePointer<UInt16>!
        _ = rawData.withUnsafeBytes { ptr   in
            
            let x = ptr.bindMemory(to: UInt16.self )
            bytes =   x.baseAddress
        }
        
        
        var p:UnsafePointer<UInt16> = bytes
        var ptr:UnsafePointer<UInt8>?
        
        p.withMemoryRebound(to: UInt8.self, capacity: 1){
            ptr = $0
            
        }
        let p0:UnsafePointer<UInt8> = ptr!
        
        identifier = bytes.pointee
        p = bytes + 1
        let op = p.pointee.bigEndian
        //print("#######################")
        qr = CChar(op >> 15)
        if qr == 0{
            //NSLog("#######################DNS req")
        }else {
            let c = p.pointee.bigEndian & 0x000F
            if c == 0 {
                //NSLog("#######################DNS resp OK")
            }else {
                //NSLog("#######################DNS resp err:\(c)")
            }
            
            
        }
        
        p = p + 1
        reqCount = p.pointee.bigEndian
        p = p + 1
        answerCount = p.pointee.bigEndian
        p = p + 1
        
        p += 2
        ptr = ptr?.advanced(by: 12)
        
        if qr == 0 {
            count = reqCount
        }else {
            count = answerCount
        }
        let  endptr:UnsafePointer<UInt8> = ptr!.advanced(by: rawData.count-6*2)
        for _ in 0..<reqCount {
            var domainString:String = ""
            var  domainLength = 0
            while (ptr?.pointee != 0x0) {
                let len = Int((ptr?.pointee)!)
                ptr = ptr?.successor()
                
                if (ptr?.distance(to:endptr))! < len   {
                    AxLogger.log("DNS error return ",level: .Debug)
                    
                }else {
                    if let s = NSString(bytes: ptr!, length: len, encoding: String.Encoding.utf8.rawValue){
                        domainString = domainString + (s as String) + "."
                        ptr = ptr! + Int(len)
                        domainLength += len
                        
                        domainLength += 1
                    }
                    
                    
                }
                
            }
            ptr = ptr?.advanced(by: 1)
            memcpy(&qType, ptr, 2)
            qType = qType.bigEndian
            ptr =  ptr?.advanced(by: 2)
            memcpy(&qClass, ptr, 2)
            qClass = qClass.bigEndian
            ptr = ptr?.advanced(by: 2)
            
            queryDomains.append(domainString)
            if qr == 1  {
                if (ptr?.distance(to: endptr))! <= 0{
                    return
                }
                
            }
        }
        //NSLog("---- %@", data)
        print("answerCount \(answerCount)")
        if qr == 1{
            for _ in 0..<answerCount {
                if ((ptr?.distance(to: endptr))! <= 0 ) {
                    print("error 0")
                    finished = false
                    return
                }
                var px:UInt16 = 0
                memcpy(&px, ptr, 2)
                ptr = ptr?.advanced(by: 2)
                px = px.bigEndian
                let pxx = px >> 14
                var domain:String = ""
                if pxx == 3 {
                    //NSLog("cc %d", pxx)
                    let offset:UInt16 = px & 0x3fff
                    
                    var ptr0:UnsafePointer<UInt8>? //=  UnsafePointer<UInt8>.ini
                    bytes.withMemoryRebound(to: UInt8.self, capacity: 1){
                        ptr0 = $0
                    }
                    
                    
                    
                    ptr0 =  ptr0?.advanced(by:Int(offset))
                    
                    domain = DNSPacket.findLabel(ptr0!, org: p0)
                }else {
                    // packet 不全，导致后面无法解析
                    finished = false
                    return
                }
                
                
                var t:UInt16 = 0
                
                memcpy(&t, ptr, 2)
                t = t.bigEndian
                guard let type :QTYPE = QTYPE(rawValue: t) else {
                    print("error 1")
                    return
                }
                ptr = ptr?.advanced(by: 2)
                var qclass:UInt16 = 0
                memcpy(&qclass, ptr, 2)
                qclass = qclass.bigEndian
                ptr  =  ptr?.advanced(by: 2)
                var ttl:Int32 = 0
                memcpy(&ttl, ptr, 4)
                ttl = ttl.byteSwapped
                ptr = ptr?.advanced(by: 4)
                
                var len:UInt16 = 0
                
                memcpy(&len, ptr, 2)
                len = len.bigEndian
                ptr = ptr?.advanced(by: 2)
                
                var domainString:String = ""
                var  domainLength = 0
                if type == .a {
                    var ip:Int32 = 0
                    memcpy(&ip, ptr, Int(len))
                    ip = ip.byteSwapped
                    domainString = "\(ip>>24 & 0xFF).\(ip>>16 & 0xFF).\(ip>>8 & 0xFF).\(ip & 0xFF)"
                    ptr = ptr?.advanced(by:  Int(len))
                    ipString.append(domainString)
                }else if type == .a6 {
                    
                    let buffer = NSMutableData()
                    memcpy(buffer.mutableBytes, ptr, Int(len))
                    ptr = ptr?.advanced(by:  Int(len))
                    AxLogger.log("IPv6 AAAA record found \(buffer) ",level: .Notify)
                }else if type == .cname{
                    print("found cname")
                    while (ptr?.pointee != 0x0) {
                        //压缩算法
                        if ptr?.pointee == 0xC0 {
                            var c:UInt16 = 0
                            memcpy(&c, ptr!, 2)
                            c = c.byteSwapped
                            c = c ^ 0xC000
                            
                            let p = p0.advanced(by: Int(c))
                            let l = DNSPacket.findLabel(p, org: p0)
                            domainString += l
                            print("\(l) \(domainString)")
                            ptr = ptr?.advanced(by: 2)
                            break
                        }
                        let len = Int((ptr?.pointee)!)
                        ptr = ptr?.successor()
                        
                        if (ptr?.distance(to:endptr))! < len   {
                            finished = false
                            print("error")
                            return
                            
                        }
                        
                        if let s = NSString.init(bytes: ptr!, length: len, encoding: String.Encoding.utf8.rawValue) {
                            domainString = domainString + (s as String) + "."
                        }
                        
                        
                        ptr = ptr?.advanced(by:  Int(len))
                        domainLength += len + 1
                        print("#" + domainString)
                    }
                    if ptr?.pointee == 0x00 {
                        ptr = ptr?.advanced(by: 1)
                    }
                    
                }
                answerDomains[domain] = domainString
                AxLogger.log("DNS \(domain),\(domainString)",level: .Debug)
                
            }
        }
        finished = true
        
        if let d = queryDomains.first {
            if qr == 0 {
                AxLogger.log("DNS Request: \(d)",level: .Debug)
                
            }else {
                //NSLog("DNS Response Packet %@", d)
                AxLogger.log("DNS Response:\(ipString)" ,level: .Debug)
                if    !self.ipString.isEmpty {
                    let r = DNSCache.init(d: d, i: ipString)
                    //MARK --fixme
                    SFSettingModule.setting.addDNSCacheRecord(r)
                    
                }else {
                    AxLogger.log("DNS  IN not found record \(d)", level: .Error)
                }
            }
            
        }
        
        
        //super.init()
    }
    static func findLabel(_ ptr0:UnsafePointer<UInt8>,org:UnsafePointer<UInt8>) ->String {
        var ptr:UnsafePointer<UInt8> = ptr0
        var domainString:String = ""
        var  domainLength = 0
        while (ptr.pointee != 0x0) {
            if ptr.pointee == 0xC0{
                var c:UInt16 = 0
                memcpy(&c, ptr, 2)
                c = c.byteSwapped
                c = c ^ 0xC000
                
                let p = org.advanced(by: Int(c))
                let l = DNSPacket.findLabel(p,org: org)
                domainString += l
                print("recv \(l) \(domainString)")
                ptr = ptr.advanced(by: 2)
                break
            }
            let len = Int(ptr.pointee)
            ptr = ptr.successor()
            
            //       if ptr.distanceTo(endptr) < len   {
            //                NSLog("error return ")
            //            }
            if let s =  NSString.init(bytes: ptr, length: len, encoding: String.Encoding.utf8.rawValue)  {
                
                
                domainString = domainString + (s as String)  + "."
            }
            
            ptr = ptr + Int(len)
            
            domainLength += len
            
            domainLength += 1
            
        }
        
        return domainString
    }
    deinit{
        AxLogger.log("DNSPacket deinit",level: .Debug)
    }
    static func genPacketData(_ ips:[String],domain:String,identifier:UInt16) ->Data {
        //IPv4
        let respData = SFData()
        respData.append(identifier)
        let x:UInt16 = 0x8180
        let y:UInt32 = 0x00010000 + UInt32(ips.count)
        let z:UInt32 =  0x00000000
        respData.append(x.bigEndian)
        respData.append(y.bigEndian)
        respData.append(z.bigEndian)
        let xx = domain.components(separatedBy: ".")
        for p in xx {
            let len:UInt8 = UInt8(p.count)
            respData.append(len)
            respData.append(p)
        }
        respData.append(UInt8(0x00)) // .在那里
        
        respData.append(UInt16(0x0001).bigEndian)
        respData.append(UInt16(0x0001).bigEndian)
        
        for ip in ips {
            //bug here ,compress bug
           
            
            respData.append(UInt16(0xC00C).bigEndian)
            respData.append(UInt16(0x0001).bigEndian)
            respData.append(UInt16(0x0001).bigEndian)
            respData.append(UInt32(0x000d2f00).bigEndian)
            respData.append(UInt16(0x0004).bigEndian)
            
            let ipD:UInt32  = inet_addr(ip.cString(using: String.Encoding.utf8)!)
            respData.append(ipD)
        }
        
        return respData.data
    }
}

