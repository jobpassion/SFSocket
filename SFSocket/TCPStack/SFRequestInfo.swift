//
//  SFRequest.swift
//  Surf
//
//  Created by yarshure on 16/1/15.
//  Copyright © 2016年 yarshure. All rights reserved.
//

import Foundation

import SwiftyJSON
let KEEP_APPLE_TCP = true
class SFRequestInfo {
    
    var mode:SFConnectionMode = .TCP //tcp http https
    var url:String = ""
    //var requestId:Int = 0
    var app = "" //user-agent
    var interfaceCell:Int64 = 0
    var localIPaddress:String = ""
    var remoteIPaddress:String = ""
    var sTime:Date// = Date.init(timeIntervalSince1970: 0)
    var estTime = Date()
    var status:SFConnectionStatus = .Start
    var closereason:SFConnectionCompleteReason = .noError
    var delay_start:Double = 0.0
//    var req:NSMutableData = NSMutableData() //req header
//    var resp:NSMutableData = NSMutableData() //respond header
    var started:Bool = false
    var reqHeader:SFHTTPRequestHeader?
    var respHeader:SFHTTPResponseHeader?
    var respReadFinish:Bool = false
    //var policy:SFPolicy = .Direct
    var recvSpped:UInt = 0
    var waitingRule:Bool = false //Rule 结果没返回需要等待DNS request
    var limit:Bool = false
    var ruleStartTime:Date = Date()
   
    var proxy:SFProxy?
    var rule:SFRuler = SFRuler()
    var inComingTime:Date = Date()
    
    var traffice:SFTraffic = SFTraffic()
    
    var speedtraffice:SFTraffic = SFTraffic()//用于cache 速度 traffice
    
    var activeTime = Date() //last active time
    var eTime = Date.init(timeIntervalSince1970: 0) //send time
    
    var reqID:Int
    var subID:Int
    var lport:Int = 0//lsof -n -i tcp:ip@port
    var dbID:Int = 0
    //var pcb_closed = false 减少不必要的状态机
    // set client not closed
    var client_closed = false // 0 pcb alive ,1 dead
    // set SOCKS not up, not closed
    var socks_up = false
    var socks_closed = false

    #if LOGGER
    var sendData:Data = Data()
    var recvData:Data = Data()
    #endif
    init(rID:Int,sID:Int = 0) {
        reqID = rID
        subID = sID
        sTime = Date()
    }
    func isSubReq() ->Bool {
        if subID == 0 {
            return true
        }else {
            return false
        }
    }
    var host:String {
        var result = ""
        if let r = reqHeader {
            if !r.ipAddressV4.isEmpty {
                result = r.ipAddressV4
            }else {
                result =  r.Host
            }
            
            
        }else {
            result = remoteIPaddress
        }
        return result
    }
    var port:Int{
        if let r  = reqHeader{
            return r.Port
        }
        return 80
    }

    func updateInterface(_ data:Data){
        
    }
    func updateSpeed(_ c:UInt, stat:Bool)  {
        if c > 0 {
            if stat{
                //traffice.addRx(Int(c))
            }
            
            let now = Date()
            let ts = now.timeIntervalSince(activeTime)
            let msec = UInt(ts*1000) //ms
            if msec == 0 {
                recvSpped = c
            }else {
                recvSpped = c / msec
            }
            
            if recvSpped > SKit.env.LimitSpeedSimgle {
                limit = true
            }else {
                limit = false
            }
//            #if DEBUG
//           //AxLogger.log("\(url) speed: \(msec)/\(recvSpped) ms \n",level:.Trace)
//            #endif
            
        }
    }
    var ruleTiming:TimeInterval {
        get{
            return Date().timeIntervalSince(ruleStartTime)
        }
    }
    var connectionTiming:TimeInterval {
        get {

            if estTime.timeIntervalSince(sTime) < 0.0 {
                return 0

            }
            return estTime.timeIntervalSince(sTime)
        }
        set(newT) {
            estTime = Date.init(timeInterval: newT, since: sTime)
            //self.connectionTiming = newT
        }
    }
    var transferTiming:TimeInterval {
        get {

            if activeTime.timeIntervalSince(estTime) < 0.0 {
                return 0

            }
            return activeTime.timeIntervalSince(estTime)
        }
        set (newT){
            activeTime = Date.init(timeInterval: newT, since: estTime)
            //self.transferTiming = newT
        }
    }
    var idleTimeing:TimeInterval {
        get {
            
            let now = Date()
            return now.timeIntervalSince(activeTime)
        }
    }
    var workTimeing:String {
        get {
            let now = Date()
            let ts =  now.timeIntervalSince(sTime)
            return String(format: "Start: %.2f ms", ts*1000)
        }
    }
    func  shouldCloseClient() ->Bool {
        var close = true
//        return false
        if KEEP_APPLE_TCP {
            if mode == .TCP {
                if url.hasPrefix("17."){
                    close = false
                    
                }
            }else {
                if url.range(of: "apple.com") != nil{
                    close = false
                    
                }
            }
 
        }
//        if connectionTiming <= 0 || transferTiming <= 0{
//            close = false
//        }
//        NSLog("%@ connectionTiming %.02f transferTiming %.02f",url, connectionTiming,transferTiming)
        return close
    }

    var runing:TimeInterval {
        get {
            return eTime.timeIntervalSince(sTime)
        }
    }
    func respObj() -> [String:AnyObject] {
        var r :[String:AnyObject] = [:]
        r["mode"] = mode.description as AnyObject?
        r["url"] = url as AnyObject?
        r["app"] = app as AnyObject?
        
        r["start"] = NSNumber.init(value: sTime.timeIntervalSince1970)
        r["status"] = status.description as AnyObject?
        r["closereason"] = closereason.description as AnyObject?
        if mode != .TCP {
            if let req = reqHeader {
                r["reqHeader"] =  req.headerString(nil) as AnyObject?
            }
            if let resp = respHeader {
                r["respHeader"] = resp.headerString( nil) as AnyObject?
            }
            
        }
        r["reqID"] = NSNumber.init(value: reqID)
        r["subID"] = NSNumber.init(value: subID)
        //r["proxyName"]  = rule.proxyName
        //r["Policy"] = policy.description
        //r["name"] = rule.name
        //r["type"] = NSNumber.init(int: Int32(rule.type.rawValue))
        //r["ruleTime"] = NSNumber.init(double: ruleTime)
        r["Est"] = NSNumber.init(value: connectionTiming)
        
        r["transferTiming"] = NSNumber.init(value:transferTiming)
        //print("############\(rule.resp())")
        r["Rule"] = rule.resp() as AnyObject?
        
        
        r["Traffic"] = traffice.resp() as AnyObject?
//        r["tx"] = NSNumber.init(unsignedInteger:traffice.tx)
//        r["rx"] = NSNumber.init(unsignedInteger: traffice.rx)
        
        r["port"] = NSNumber.init(value: lport)
        r["end"] = NSNumber.init(value: eTime.timeIntervalSince1970)
        r["interface"] = NSNumber.init(value:interfaceCell)
        r["localIP"] = localIPaddress as AnyObject?
        r["remoteIP"] = remoteIPaddress as AnyObject?
        return r
    }
    func map(_ j:JSON){
        
        self.mode = SFConnectionMode(rawValue:j["mode"].stringValue)!
        self.url = j["url"].stringValue
        self.app = j["app"].stringValue
        self.lport = j["port"].intValue
        var  s = j["start"]
        self.sTime = Date.init(timeIntervalSince1970: s.doubleValue)
        self.status = SFConnectionStatus(rawValue:j["status"].stringValue)!
        let reason = j["closereason"].intValue
        self.closereason = SFConnectionCompleteReason(rawValue:reason)!
        
        if mode != .TCP {
            var head = j["respHeader"]
            if head.error == nil {
                let str = head.stringValue
                if let d = str.data(using: String.Encoding.utf8) {
                    if let h = SFHTTPResponseHeader.init(data: d) {
                        self.respHeader = h
                    }
                    
                    
                }
            }
            
            head = j["reqHeader"]
            if head.error == nil {
                let str = head.stringValue
                if let d = str.data(using: String.Encoding.utf8) {
                    if let h = SFHTTPRequestHeader.init(data: d) {
                         self.reqHeader = h
                    }
                   
                }
            }
            
        }
        
        let est = j["Est"]
        connectionTiming = Double(est.stringValue)!
        let rjson = j["Rule"]
        rule.mapObject(rjson)
        
        self.reqID = j["reqID"].int!
        self.subID = j["subID"].int!
        let transf = j["transferTiming"]
        self.transferTiming = Double(transf.stringValue)!
        
        self.traffice.mapObject(j: j["Traffic"])

        
        self.eTime = Date.init(timeIntervalSince1970: j["end"].doubleValue)
        self.interfaceCell = j["interfaceCell"].int64Value
        self.localIPaddress = j["localIP"].stringValue
        self.remoteIPaddress = j["remoteIP"].stringValue
        
    }

    func dataDesc(_ d:Date) ->String{
        
        let zone = TimeZone.current
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.dateFormat = "HH:mm:ss"
        //formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: d)
    }
    func writeFLow(){
        //AxLogger.log("[SFRequestInfo-\(reqID)] write data",level: .Debug)
        #if LOGGER
        let url1 = groupContainerURL().appendingPathComponent("\(url)\(reqID)_\(sTime)send.bin")
        try! sendData.write(to: url1, options: .atomic)
        let url2 = groupContainerURL().appendingPathComponent("\(url)\(reqID)_\(sTime)recv.bin") 
        try! recvData.write(to: url2, options: .atomic)
        #endif
    }

    func updateSendTraffic(_ t:Int){
        let stat = SFVPNStatistics.shared
        traffice.addTx(x: t)
        if interfaceCell == 0 {
            //WIFI
            stat.wifiTraffice.addTx(x: t)
        }else {
            stat.cellTraffice.addTx(x: t)
        }
        if let _  = proxy {
           stat.proxyTraffice.addTx(x: t)
        }else {
            stat.directTraffice.addTx(x: t)
        }
        activeTime = Date()
    }
    func updaterecvTraffic(_ t:Int){
        let stat = SFVPNStatistics.shared
        traffice.addRx(x: t)
        if interfaceCell == 0 {
            //WIFI
            stat.wifiTraffice.addRx(x: t)
        }else {
            stat.cellTraffice.addRx(x: t)
        }
        if let _  = proxy {
            stat.proxyTraffice.addRx(x: t)
        }else {
            stat.directTraffice.addRx(x: t)
        }
        activeTime = Date()
    }
    deinit {
        
        writeFLow()
        
        //
//        reqHeader = nil
//        respHeader = nil
        //NSLog("[SFRequestInfo-\(reqID)] \(mode.description) \(url) deinit \(traffice.rx):\(traffice.tx)")
        //AxLogger("")
    }
}
extension SFRequestInfo: Equatable {}

func ==(lhs:SFRequestInfo,rhs:SFRequestInfo) -> Bool {
    
    return (lhs.reqID == rhs.reqID) && (lhs.subID == rhs.subID)
}
