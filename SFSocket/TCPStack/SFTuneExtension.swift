//
//  SFTuneExtension.swift
//  Surf
//
//  Created by 孔祥波 on 8/2/16.
//  Copyright © 2016 yarshure. All rights reserved.
//
//这个文件不会被主app 使用
import Foundation
import ObjectMapper
import SwiftyJSON
import AxLogger
extension SFRequestInfo {
    func findProxy(_ r:SFRuleResult,cache:Bool) {
        
        rule = r.result
        rule.timming = self.ruleTiming
        if cache {
            SFTCPConnectionManager.manager.addRuleResult(r)
        }
        
        let x = String.init(format: "%.2f second", rule.timming)
        AxLogger.log("\(reqID)-\(host) found rule now timing \(x) ,begin find proxy rule:\(rule.policyString())",level: .Trace)
        //NSLog("%@ %@",dest,useragent)
        
        switch  rule.policy{
        case .Direct:
            
            break
        case .Random:
            self.proxy = SFSettingModule.setting.randomProxy()
        case .Reject:
            
            break
        case .Proxy:
            guard let proxy = SFSettingModule.setting.proxyByName(rule.proxyName) else {
                return
            }
            self.proxy = proxy
            //reqInfo.rule.policy = .Proxy
            
        }
        let message3 = String.init(format: "%@ %@",url, self.rule.policy.description)
        
        AxLogger.log("\(message3) recv result , now exit waiting",level:.Debug)
        if waitingRule {
            waitingRule = false
        }
        if let p = proxy {
            rule.proxyName = p.proxyName
        }
        
    }
    func checkReadFinish(_ data:Data) ->(Bool,Int){
        let  len:Int = data.count
        guard let header = respHeader else {return (false,0)}
        var BodyLength  = header.contentLength
        // let headLength = header.length
        
        if self.app.hasSuffix("WeChat"){
            if let size = header.params["Size"]{
                
                self.respHeader!.mode = .ContentLength
                self.respHeader!.bodyLeftLength = Int(size)!
            }
        }
        
        
        //        for (k,v) in header.params {
        //            NSLog("HEADER PARAMS:%@ %@", k,v)
        //        }
        
        
        if header.mode == .ContentLength {
           
            
            AxLogger.log("HTTP \(header.mode) BodyLength: \(BodyLength) left:\(header.bodyLeftLength) recv len:\(len)", level: .Debug)
            
            if header.bodyLeftLength  == 0 {
                respReadFinish = true
                return (respReadFinish,0)
            }
            if header.bodyLeftLength <= len  {//勾了
                let used = header.bodyLeftLength
                respReadFinish = true
                //let left = len - header.bodyLeftLength
                //traffice.addRx(x: header.bodyLeftLength)
                header.bodyLeftLength = 0
                //print("\(url) Body Recv \(header.bodyReadLength): \(BodyLength)")
                
                return (respReadFinish,used)
            }else {
                //header.bodyLeftLength > len
                header.bodyLeftLength -= len
                //traffice.addRx(x: len)
                return (false,len)
            }
        }else if header.mode == .TransferEncoding{
            //traffice.addRx(x: len)//bodylen
            AxLogger.log("HTTP \(header.mode) received:\(traffice.rx)",level:.Trace)
            let (r,used) = header.parser(data)
            respReadFinish = r
            return (r,used)
        }else {
            //            if contentLength !== 0 {
            //
            //            }else {
            //
            //            }
            AxLogger.log("HTTP header .mode error \(header.params)",level:.Debug)
            //traffice.addRx(x: len)
            //header.length += len
            header.contentLength += len
            //used += len
            return (false,len)
        }
        
    }
    
    func shouldClose() ->Bool {
        
        if mode == .TCP {
            if idleTimeing > SKit.TCP_MEMORYWARNING_TIMEOUT{
                return true
            }else {
                return false
            }
        }
        
        guard let resp  = respHeader else {return false}
        guard let req = reqHeader else {return false}
        var result = false
        if req.method == .CONNECT {
            if idleTimeing > SKit.TCP_MEMORYWARNING_TIMEOUT {
                result = true
            }
        }else {
            if let c = resp.params["Connection"], c == "close"{
                
                if idleTimeing > SKit.TCP_MEMORYWARNING_TIMEOUT  {
                    result = true
                }
            }
        }
        
        return result
    }
}

extension SFProxy{
    var connectHost:String {
        var host:String = serverAddress
        if !serverIP.isEmpty {
            if SFEnv.ipType == .ipv6 {
                host = "::ffff:" + serverIP
            }else {
                host = serverIP
            }
            
        }
        return host
    }
}
extension SFHTTPRequestHeader {
    func checkRewrite() ->Bool{
        //rewrite
        if  let r =  SFSettingModule.setting.rule{
            if let ruler = r.rewriteRule(self.Url){
                if ruler.type == .header {
                    if let r = self.Url.range(of: ruler.name){
                        self.Url.replaceSubrange(r, with: ruler.proxyName)
                        let dest = ruler.proxyName
                        let dlist = dest.components(separatedBy: "/")
                        for dd in dlist {
                            if !dd.isEmpty && !dd.hasPrefix("http"){
                                self.params["Host"] = dd
                                return true
                            }
                            
                        }
                        
                        
                        
                    }
                }
                
                
            }
        }
        return false
    }
}

extension SFHTTPResponseHeader {
    func parser(_ data:Data) ->(Bool,Int){
        
        var used:Int = 0
        let total = data.count
        let opt = NSData.SearchOptions.init(rawValue: 0)
        var packets :[chunked] = []
        AxLogger.log("bodyLeftLength left:\(bodyLeftLength) new data len:\(data.count)",level: .Trace)
        if let chunk_packet = chunk_packet {
            //last 没有读完
            if total >= chunk_packet.leftLen {
                
                used += chunk_packet.leftLen
                bodyLeftLength = 0
                AxLogger.log("used:\(used) left:\(bodyLeftLength) Finished",level: .Trace)
                self.chunk_packet = nil
                //inst 是结束\r\n
                
                used += sepData.count
            }else {
                
                used += total
                self.chunk_packet!.leftLen -= used
                bodyLeftLength -= used
                AxLogger.log("used:\(used) left:\(bodyLeftLength) not Finished ",level: .Trace)
                return (false,used)
            }
        }else {
            ////兼容完成bug是问题
            if total >= bodyLeftLength {
                used += bodyLeftLength
            }else {
                used += total
            }
        }
        while used < total {
            
            //let start = data.startIndex.advanced(by: used)
            //let end = data.startIndex.advanced(by: data.count - used)
            let r = data.range(of:sepData, options: opt, in: Range(used ..< data.count)  )
            
            if let r =  r  {
                AxLogger.log("used length: \(used) sepdata location:\(r)",level: .Trace)
                //let l = data.subdata(with: NSMakeRange(used, r.location - used))
                let l = data.subdata(in: Range(used ..< r.upperBound ))
                
                used += l.count // count length
                used += r.length() //算上\r\n
                
                let c_leng = Int(hexDataToInt(d: l))
                contentLength += c_leng
                if c_leng == 0 {
                    
                    if let r2 = data.range(of: sepData, options: opt, in: Range(used ..< data.count )){
                        used += r2.length()
                    }
                    if used == total{
                        AxLogger.log("used length: \(used) Last Find",level: .Trace)
                        bodyLeftLength = 0
                        chunk_packet = nil
                        //finished = true
                        return (true,used)
                    }
                    
                }
                AxLogger.log("thunk len: \(c_leng) check:\(used + c_leng):\(total)",level: .Debug)
                if used + c_leng <= total {
                    let p = chunked.init(l: c_leng,left:0)
                    if used + c_leng == total {
                        //缺\r\n
                        chunk_packet = nil//chunked.init(l: c_leng,left:2)
                        bodyLeftLength = sepData.count
                        //p.data = data.subdataWithRange(NSMakeRange(used, c_leng))
                    }else {
                        //多了怎么算
                        packets.append(p)
                        used += c_leng
                        
                        used += sepData.count //\r\n chunk fins
                        AxLogger.log("found chunk fins\(used) \(r)  \(used) ", level: .Debug)
                    }
                    
                }else {
                    
                    bodyLeftLength = c_leng - (total - used)
                    chunk_packet = chunked.init(l: c_leng, left: bodyLeftLength)
                    used = total
                    AxLogger.log("found \(used + c_leng ) left:\(bodyLeftLength)  \(r) \(used) ", level: .Debug)
                    return (false,used)
                }
                
            }else {
                AxLogger.log("Don't Find sepdata",level: .Debug)
                return (false,used)
            }
            
        }
        return (false,used)
        
    }
}
extension SFProxy{
    
    func resp() ->[String:Any]{
        return ["name":proxyName as AnyObject,"host":serverAddress as AnyObject,"port":serverPort,"protocol":type.description,"method":method,"passwd":password,"tls":NSNumber.init(value: tlsEnable),"priority":NSNumber.init(value: priority),"enable":NSNumber.init(value: enable),"countryFlag":countryFlag,"isoCode":isoCode,"ipaddress":serverIP]
    }
//    static func map(_ name:String,value:JSON) ->SFProxy{
//        let i = value
//        let px = i["protocol"].stringValue as NSString
//        let proto = px.uppercased
//        var type :SFProxyType
//        if proto == "HTTP"{
//            type = .HTTP
//        }else if proto == "HTTPS" {
//            type = .HTTPS
//        }else if proto == "CUSTOM" {
//            type = .SS
//        }else if proto == "SS" {
//            type = .SS
//        }else if proto == "SOCKS5" {
//            type = .SOCKS5
//        }else {
//            type = .LANTERN
//        }
//        
//        
//        let a = i["host"].stringValue, p = i["port"].stringValue , pass = i["passwd"].stringValue , m = i["method"].stringValue
//        
//        var tlsEnable = false
//        let tls = i["tls"]
//        if tls.error == nil {
//            tlsEnable = tls.boolValue
//        }
//        
//        var enable = false
//        let penable = i["enable"]
//        if penable.error == nil {
//            enable = penable.boolValue
//        }
//        
//        var pName = name
//        if i["name"].error == nil {
//            pName = i["name"].stringValue
//        }
//        guard let sp = SFProxy.create(name: pName, type: type, address: a, port: p, passwd: pass, method: m,tls: tlsEnable) else {
//            return ObjectMapper<SFProxy>
//            return
//        }
//        
//        
//        if type == .SS {
//            //sp.udpRelay = true
//        }
//        //carsh on Mac
//        //sp.enable = enable
//        let cFlag = i["countryFlag"]
//        sp.countryFlag = cFlag.stringValue
//        let priJ = i["priority"]
//        if priJ.error == nil {
//            sp.priority = priJ.intValue
//        }
//        if i["isoCode"].error == nil {
//            sp.isoCode = i["isoCode"].stringValue
//        }
//        if i["ipaddress"].error == nil {
//            sp.serverIP = i["ipaddress"].stringValue
//        }
//        return sp
//    }
    
}
