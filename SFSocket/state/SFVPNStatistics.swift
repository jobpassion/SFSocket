//
//  SFVPNReport.swift
//  Surf
//
//  Created by yarshure on 16/3/7.
//  Copyright © 2016年 yarshure. All rights reserved.
//

import Foundation

import SwiftyJSON
import AxLogger
public class SFTraffic {
    public var rx: UInt = 0
    public var tx: UInt = 0
    public init(){
        
    }
    public func addRx(x:Int){
        rx += UInt(x)
    }
    public func addTx(x:Int){
        tx += UInt(x)
    }
    public func reset() {
        rx = 0
        tx = 0
    }
    public func txString() ->String{
        return toString(x: tx,label: "TX:",speed: false)
    }
    public func rxString() ->String {
        return toString(x: rx,label:"RX:",speed: false)
    }
    public func toString(x:UInt,label:String,speed:Bool) ->String {
        
        var s = "/s"
        if !speed {
            s = ""
        }
        #if os(macOS)
            if x < 1024{
                return label + " \(x) B" + s
            }else if x >= 1024 && x < 1024*1024 {
                return label +  String(format: "%d KB", Int(Float(x)/1024.0))  + s
            }else if x >= 1024*1024 && x < 1024*1024*1024 {
                //return label + "\(x/1024/1024) MB" + s
                return label +  String(format: "%d MB", Int(Float(x)/1024/1024))  + s
            }else {
                //return label + "\(x/1024/1024/1024) GB" + s
                return label +  String(format: "%d GB", Int(Float(x)/1024/1024/1024))  + s
            }
            #else
        if x < 1024{
            return label + " \(x) B" + s
        }else if x >= 1024 && x < 1024*1024 {
            return label +  String(format: "%.2f KB", Float(x)/1024.0)  + s
        }else if x >= 1024*1024 && x < 1024*1024*1024 {
            //return label + "\(x/1024/1024) MB" + s
            return label +  String(format: "%.2f MB", Float(x)/1024/1024)  + s
        }else {
            //return label + "\(x/1024/1024/1024) GB" + s
            return label +  String(format: "%.2f GB", Float(x)/1024/1024/1024)  + s
        }
        #endif
    }
    public func report() ->String{
        return "\(toString(x: tx, label: "TX:",speed: true)) \(toString(x: rx, label: "RX:",speed: true))"
    }
    public func reportTraffic() ->String{
        return "\(toString(x: tx, label: "TX:",speed: false)) \(toString(x: rx, label: "RX:",speed: false))"
    }
    public func resp ()-> [String:NSNumber] {
        return ["rx":NSNumber.init(value: rx) ,"tx":NSNumber.init(value: tx)]
    }
    public func mapObject(j:JSON)  {
        rx = UInt(j["rx"].int64Value)
        tx = UInt(j["tx"].int64Value)
    }
}

public enum FlowType:Int {
    case total = 1
    case current = 2
    case last = 3
    case max = 4
    case wifi = 5
    case cell = 6
    case direct = 7
    case proxy = 8
}
public final class NetFlow{
    //public static let shared = NetFlow()
    public var totalFlows:[SFTraffic] = []
    public let currentFlows:[SFTraffic] = []
    public let lastFlows:[SFTraffic] = []
    public let maxFlows:[SFTraffic] = []
    
    public var wifiFlows:[SFTraffic] = []
    public var cellFlows:[SFTraffic] = []
    
    public var directFlows:[SFTraffic] = []
    public var proxyFlows:[SFTraffic] = []
    public func update(_ flow:SFTraffic, type:FlowType){
//        var tmp:[SFTraffic]
//        switch type {
//        case .total:
//           tmp = totalFlows
//        case .current :
//           tmp = currentFlows
//        case .last :
//           tmp = lastFlows
//        case .max:
//           tmp = maxFlows
//        case .wifi:
//           tmp = wifiFlows
//        case .cell:
//           tmp = cellFlows
//        case .direct:
//            tmp = directFlows
//        case .proxy:
//            tmp = proxyFlows
//        }
        totalFlows.append(flow)
        if totalFlows.count > 60 {
            totalFlows.remove(at: 0)
        }
    }
    public func resp() -> [String : AnyObject] {
        var result:[String:AnyObject] = [:]
        var x:[AnyObject] = []
        for xx in totalFlows{
            x.append(xx.resp() as AnyObject)
        }
        result["total"] = x as AnyObject
        return result
    }
    public func mapObject(j: SwiftyJSON.JSON){
        totalFlows.removeAll(keepingCapacity: true)
        for xx in j["total"].arrayValue {
            let x = SFTraffic()
            x.mapObject(j: xx)
            totalFlows.append(x)
        }
    }
    public func flow(_ type:FlowType) ->[Double]{
        var r:[Double] = []
        for x in totalFlows {
            r.append(Double(x.rx))
        }
        return r
    }
}

open class SFVPNStatistics {
    public static let shared = SFVPNStatistics()
    public var startDate = Date()
    public var sessionStartTime = Date()
    public var reportTime = Date()
    public var startTimes = 0
    public var show:Bool = false
    public let totalTraffice:SFTraffic = SFTraffic()
    public let currentTraffice:SFTraffic = SFTraffic()
    public let lastTraffice:SFTraffic = SFTraffic()
    public let maxTraffice:SFTraffic = SFTraffic()
    
    public var wifiTraffice:SFTraffic = SFTraffic()
    public var cellTraffice:SFTraffic = SFTraffic()
    
    public var directTraffice:SFTraffic = SFTraffic()
    public var proxyTraffice:SFTraffic = SFTraffic()
    public var memoryUsed:UInt64 = 0
    public var finishedCount:Int = 0
    public var workingCount:Int = 0
    public var netflow:NetFlow = NetFlow()
    public var runing:String {
        get {
            let now = Date()
            let second = Int(now.timeIntervalSince(sessionStartTime))
            return secondToString(second: second)
        }
    }
    public func updateMax() {
        if lastTraffice.tx > maxTraffice.tx{
            maxTraffice.tx = lastTraffice.tx
        }
        if lastTraffice.rx > maxTraffice.rx {
            maxTraffice.rx = lastTraffice.rx
        }
    }
    public func secondToString(second:Int) ->String {
        
        let sec = second % 60
        let min = second % (60*60) / 60
        let hour = second / (60*60)
        
        return String.init(format: "%02d:%02d:%02d", hour,min,sec)
        

    }
    public func map(j:JSON) {
        startDate = Date.init(timeIntervalSince1970: j["start"].doubleValue) as Date
        sessionStartTime = Date.init(timeIntervalSince1970: j["sessionStartTime"].doubleValue)
        reportTime = NSDate.init(timeIntervalSince1970: j["report_date"].doubleValue) as Date
        totalTraffice.mapObject(j: j["total"])
        lastTraffice.mapObject(j: j["last"])
        maxTraffice.mapObject(j: j["max"])
        
        cellTraffice.mapObject(j:j["cell"])
        wifiTraffice.mapObject(j: j["wifi"])
        directTraffice.mapObject(j: j["direct"])
        proxyTraffice.mapObject(j: j["proxy"])
        netflow.mapObject(j: j["netflow"])
        if let c  = j["memory"].uInt64 {
            memoryUsed = c
        }
        if let tcp = j["finishedCount"].int {
            finishedCount = tcp
        }
        if let tcp = j["workingCount"].int {
            workingCount = tcp
        }
        
    }
    public func memoryString() ->String {
        let f = Float(memoryUsed)
        if memoryUsed < 1024 {
            return "\(memoryUsed) Bytes"
        }else if memoryUsed >=  1024 &&  memoryUsed <  1024*1024 {
            
            return  String(format: "%.2f KB", f/1024.0)
        }
        return String(format: "%.2f MB", f/1024.0/1024.0)
        
    }
    func resport() ->Data{
        reportTime = Date()
        memoryUsed = reportMemoryUsed()
        
        var status:[String:AnyObject] = [:]
        status["start"] =  NSNumber.init(value: startDate.timeIntervalSince1970)
        status["sessionStartTime"] =  NSNumber.init(value: sessionStartTime.timeIntervalSince1970)
        status["report_date"] =  NSNumber.init(value: reportTime.timeIntervalSince1970)
        //status["runing"] = NSNumber.init(double:runing)
        status["total"] = totalTraffice.resp() as AnyObject?
        status["last"] = lastTraffice.resp() as AnyObject?
        status["max"] = maxTraffice.resp() as AnyObject?
        status["memory"] = NSNumber.init(value: memoryUsed) //memoryUsed)
        
        let count = SFTCPConnectionManager.manager.connectionsCount
        status["finishedCount"] = NSNumber.init(value: finishedCount) //
        status["workingCount"] = NSNumber.init(value: count) //
        
        status["cell"] = cellTraffice.resp() as AnyObject?
        status["wifi"] = wifiTraffice.resp() as AnyObject?
        status["direct"] = directTraffice.resp() as AnyObject?
        status["proxy"] = proxyTraffice.resp() as AnyObject?
        status["netflow"] = netflow.resp() as AnyObject
        let j = JSON(status)
        
        
        
        
        //print("recentRequestData \(j)")
        var data:Data
        do {
            try data = j.rawData()
        }catch let error  {
            //AxLogger.log("ruleResultData error \(error.localizedDescription)")
            //let x = error.localizedDescription
            //let err = "report error"
            data =  error.localizedDescription.data(using: .utf8)!// NSData()
        }
        return data
    }
    func flowData() ->Data{
        reportTime = Date()
        memoryUsed = reportMemoryUsed()//reportCurrentMemory()
        
        var status:[String:AnyObject] = [:]
        
        status["netflow"] = netflow.resp() as AnyObject
        let j = JSON(status)
        
        
        
        
        //print("recentRequestData \(j)")
        var data:Data
        do {
            try data = j.rawData()
        }catch let error  {
            //AxLogger.log("ruleResultData error \(error.localizedDescription)")
            //let x = error.localizedDescription
            //let err = "report error"
            data =  error.localizedDescription.data(using: .utf8)!// NSData()
        }
        return data
    }
}

