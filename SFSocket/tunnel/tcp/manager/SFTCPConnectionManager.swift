//
//  TCPConnectionManager.swift
//  Surf
//
//  Created by yarshure on 15/12/25.
//  Copyright © 2015年 yarshure. All rights reserved.
//

import Foundation
import Darwin
import DarwinCore
import SwiftyJSON
import lwip
import AxLogger
import XRuler
import XProxy

public class SFTCPConnectionManager {
    
    public static let shared:SFTCPConnectionManager = SFTCPConnectionManager()
    
    public var dispatchQueue:DispatchQueue// = dispatch_queue_create("com.yarshure.dispatch_queue", DISPATCH_QUEUE_SERIAL);
    var socketQueue:DispatchQueue //= dispatch_queue_create("com.yarshure.dispatch_queue_socket", DISPATCH_QUEUE_SERIAL);
    var memoryWarninglevel:DispatchSource.MemoryPressureEvent = DispatchSource.MemoryPressureEvent.normal
    var lastMemeoryWarningDate:Date = Date()
    
    public weak var provider:TCPManagerProtocol?
    var connections:[UInt16:SFConnection] = [:]//reqID Connection
    //var connections:NSMutableDictionary = [:]
    
    public var connectionsCount:Int{
        get {
            return connections.count
        }
    }
    
    var ruleResultDynamic:[SFRuleResult] = []
    var ruleTestResult:[SFRuleResult] = []
    //var socketConnection:[SFHTTPSocketConnection] = []
    var tcpOperating:Bool = false
    public var lwip_init_finished = false
    var dispatch_timer : DispatchSourceTimer! = nil
    
    var firsttime = true
    var once : Bool = false
    var networkingScheduledTask :DispatchWorkItem!
   

    var listener:SFPcb!
    func setupLWIP(){
        listener  = init_lwip(outputFunc(), inputFunc())
        let argu = Unmanaged.passUnretained(self).toOpaque()
        tcp_arg(listener, argu)
        tcp_accept(listener, acceptFunc())
        
        self.lwip_init_finished = true
        
    }
    func outputFunc() ->netif_output_fn {
        return { xnetif,p,addr in
            guard let p = p  else {
                return err_t(ERR_BUF)
            }
            if p.pointee.next != nil{
                let payload =  p.pointee.payload
                let data = Data.init(bytes: payload!, count: Int(p.pointee.len))
                SFTCPConnectionManager.shared.writeDatagrams(data)
            }else {
                var result:Data = Data()
                var pp = p
                while(pp.pointee.next != nil){
                    let payload =  pp.pointee.payload
                    let data = Data.init(bytes: payload!, count: Int(pp.pointee.len))
                    result.append(data)
                    pp = pp.pointee.next
                }
                SFTCPConnectionManager.shared.writeDatagrams(result)
            }
            
            return err_t(ERR_OK)
        }
    }
    func inputFunc() ->netif_input_fn{
        return  { buff ,xnetif in
            var ip_version:UInt8 = 0
            if buff!.pointee.len > 0 {
                ip_version = buff!.pointee.payload.bindMemory(to: UInt8.self, capacity: 1).pointee >> 4
            }
            if ip_version == 4 {
                return ip_input(buff,xnetif)
            }
            pbuf_free(buff!)
            return err_t(ERR_OK)
        }
    }
    func acceptFunc() ->tcp_accept_fn{
        return { arg,newpcb,err in
            let unmanaged:Unmanaged<SFTCPConnectionManager>  =   Unmanaged.fromOpaque(arg!)
            let connection:SFTCPConnectionManager = unmanaged.takeUnretainedValue()
            tcp_accepted_c(connection.listener)
            connection.incomingTCP(newpcb!)
            return err_t(ERR_OK)
        }
    }
    init() {
      
        dispatchQueue =  DispatchQueue.main//DispatchQueue(label: "com.yarshure.dispatchqueue")
        socketQueue =  DispatchQueue(label:"com.yarshure.socketqueue")
        
        
        setupLWIP()
        self.start()
        
        self.installMemoryWarning()
    
    }

    public func start(){
    
        self.startWithInterval(SKit.lwip_timer_second)
        
    }
    func checkConnectionStatus() {
    
        for (_,c) in connections {
            c.checkStatus()
            
            
        }
    }
    
    internal func closeAllConnection(){
        for (_,x) in connections {
            //guard let c  = x  else {return}
            //x.manager = nil
            
            saveConnectionInfo(x)
            x.client_murder()
        }
        connections.removeAll()
    }
    
    func setMTU(_ mtu:Int){
        
    }
    func saveConnectionInfo(_ ref:Connection) {
        if ProxyGroupSettings.share.historyEnable {
            
            let helper = RequestHelper.shared
            let info = ref.reqInfo
            helper.saveReqInfo(info)
            
        }
    }
    func removeConnectionRef(_ ref:SFConnection){
        //ref.manager = nil
        //connections.remo
        //SKit.log("removeConnectionRef \(ref.cIDString) left:\(connections.count-1)",level: .Debug)
        let sport  = ref.info.tun.port
        
        saveConnectionInfo(ref)
        connections.removeValue(forKey: sport)
        
        
    }
    
    public func writeDatagrams(_ data:Data){
        
        DispatchQueue.main.async(execute:{[unowned self] in
            if let p = self.provider {
                p.writeDatagram(packets: data,proto: AF_INET)
            }
            
        })
        
        
        
    }
}
extension SFTCPConnectionManager{
    func installMemoryWarning(){
        
        
        let source = DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: nil)
        
        //let q = DispatchQueue.init(label: "test")
        dispatchQueue.async {
            source.setEventHandler {[unowned self] in
                let event:DispatchSource.MemoryPressureEvent  = source.mask
                print(event)
                switch event {
                case DispatchSource.MemoryPressureEvent.normal:
                    print("normal")
                case DispatchSource.MemoryPressureEvent.warning:
                    print("warning")
                case DispatchSource.MemoryPressureEvent.critical:
                    print("critical")
                default:
                    break
                }
                self.recvMemoryWarning(event)
                
            }
            source.resume()
        }
    }
    func recvMemoryWarning(_ level:DispatchSource.MemoryPressureEvent){
        self.memoryWarninglevel = level
        let message = String.init(format:"recvMemoryWarning %d connection:%d", level.rawValue,connections.count)
        SKit.log(message,level: .Warning)
        switch level {
        case DispatchSource.MemoryPressureEvent.normal:
            //logStream.write("Memory Warning NORMAL")
            break
        case DispatchSource.MemoryPressureEvent.warning: break
            //logStream.write("Memory Warning WARN")
            
            
        case DispatchSource.MemoryPressureEvent.critical:
            let now = Date()
            if now.timeIntervalSince(lastMemeoryWarningDate) > 5 {
                lastMemeoryWarningDate = now as Date
                //logStream.write("Memory Warning CRITICAL \(memoryUsed())")
                
            }
            
            
        default:
            break
        }
        cleanMemory()
        
    }
    func cleanMemory() {
        switch self.memoryWarninglevel {
        case DispatchSource.MemoryPressureEvent.normal:
            break
        case DispatchSource.MemoryPressureEvent.warning:
            closeTW()
        case DispatchSource.MemoryPressureEvent.critical:
            closeTW()
            
            ruleTestResult.removeAll()
            dispatchQueue.async(execute: {
                [unowned self] in
                for (_,c) in self.connections {
                    c.memoryWarning(self.memoryWarninglevel)
                    
                }
                
            })
            
        default:
            break
        }
        //NSLog(reportMemory())
    }
    
    public func incomingTCP(_ tcp:SFPcb){
        //tcp_accepted_c(listener)
        let  srcip:UnsafeMutablePointer<UInt32> = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
        let  dstip:UnsafeMutablePointer<UInt32> =  UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
        let   sport:UnsafeMutablePointer<UInt16> =  UnsafeMutablePointer<UInt16>.allocate(capacity: 1)
        let   dport:UnsafeMutablePointer<UInt16> =  UnsafeMutablePointer<UInt16>.allocate(capacity: 1)
        defer { srcip.deallocate(capacity: 1) }
        defer { dstip.deallocate(capacity: 1) }
        defer { sport.deallocate(capacity: 1) }
        defer { dport.deallocate(capacity: 1) }

        
        pcbinfo(tcp,srcip,dstip, sport,dport)
        
        //        let xport = dport.byteSwapped
        //        let yport = dport.bigEndian
        var c:SFConnection
        SKit.log("incomming tcp :\(srcip.pointee):\(sport.pointee) \(dstip.pointee):\(dport.pointee) ", level: .Info)
        let ip:UInt32 =  inet_addr(SKit.proxyIpAddr.cString(using: String.Encoding.utf8)!)  //0x030000f0
        
        if isHTTP(tcp,ip) {
            
            if sport.pointee == UInt16(SKit.httpProxyPort) || sport.pointee == UInt16(80){
                c = SFHTTPConnection(tcp: tcp,host:srcip.pointee,port:sport.pointee,m:self)
            }else if sport.pointee == UInt16(SKit.HttpsProxyPort)   {
                c = SFHTTPSConnection(tcp: tcp,host:srcip.pointee,port:sport.pointee,m:self)
            }else {
                //NSLog("################$$$$$$$$$$$$$$$$$incoming \(sport)")
                //logStream.write("incoming  \(sport)")
                //c = SFHTTPSConnection(tcp: tcp,host:srcip,port:sport,m:self)
                return
            }
            
            //SKit.log("http connection incoming \(c)",level: .Debug)
            
        }else{
            let ip:UInt32 =  inet_addr(SKit.xxIpAddr.cString(using: String.Encoding.utf8)!)
            if srcip.pointee == ip {
                 c = SFTCPConnection(tcp: tcp,host:dstip.pointee,port:dport.pointee,m:self)
                //c = SFXConnection(tcp: tcp,host:dstip.pointee,port:dport.pointee,m:self)
            }else {
                 c = SFTCPConnection(tcp: tcp,host:dstip.pointee,port:dport.pointee,m:self)
            }
           
            
        }
        
        //test()
        //print(recentRequestData())
        c.configLwip()
        c.manager = self
        connections[dport.pointee] = c
        if connections.count > SKit.LimitTCPConnectionCount_DELAY {
            c.reqInfo.delay_start = Double(connections.count - SKit.LimitTCPConnectionCount_DELAY) * SKit.TCP_DELAY_START
        }
        
        //usleep(50)
    }
 
    public func cleanConnection() {
        SKit.log("[SFTCPConnectionManager] Connection :\(connections.count)",level: .Notify)
        //self.cancel()
        dispatchQueue.async { [unowned self] in
            self.closeAllConnection()
            
            self.ruleTestResult.removeAll()
            //clear connection
            SKit.proxy?.cellToWill()
            SKit.log("[SFTCPConnectionManager] Connection clean Done!",level: .Notify)
        }
        //
        //        closeTW()
    }
    
    public func cancel() {
        
        SKit.log("should cancel timer", level: .Debug)
    }
    public func resume() {
        startWithInterval(SKit.lwip_timer_second)
    }
    func startWithInterval(_ interval:Double) {
        self.firsttime = true
        self.cancel()
        self.dispatch_timer =  DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags.init(rawValue: 0), queue: dispatchQueue)
        
        
        
        
        let deadline = DispatchTime.now()
        
        dispatch_timer.schedule(deadline: deadline, repeating: interval, leeway: .nanoseconds(0))
        
        dispatch_timer.setEventHandler {  
           tcp_tmr()
           
            
        }
        dispatch_timer.setCancelHandler {//[unowned self] in
            SKit.log("dispatch_timer cancel", level: .Info)
        }
        dispatch_timer.resume()
        
        
    }
   public  func device_read_handler_sendPackets3(_ packets:[Data],complete:@escaping ((Error?) -> Void)){
        //网络切换的时候不会crash
        //debugLog("device_read_handler_sendPackets")
        if lwip_init_finished == false {
            //init not finish ,input packet will
            //drop the packet
            //SKit.log("lwip init not finish drop packet \(data)",level: .Info)
            SKit.log("lwip_init_finished false",level: .Error)
            return
        }
        
        dispatchQueue.async {[weak self] () -> Void in
            let d1 = Date()
            let ps = packets
            if let strongSelf = self {
                //                for (_,c) in strongSelf.connections {
                //                     c.checkStatus()
                //
                //                }
                
                //bug here,todo fix tcp_in.c Line 1076] tcp_receive: lwip assertion failure: tcp_receive: valid queue length
                for packet in ps {
                   
                   inputData(packet,packet.count)
                   
                }
                _ = strongSelf.networkingScheduledTask
                
                
                strongSelf.checkConnectionStatus()
            }
            let d2 = Date().timeIntervalSince(d1)
            if d2 > 1.0 {
                let m = String.init(format: "device_read_handler_sendPackets %.2f" ,d2)
                SKit.log(m,level: .Warning)
            }
            
            DispatchQueue.main.async {
                complete(nil)
            }

        }
    }

    public func clearRule() {
        dispatchQueue.async  { [unowned self] in
            self.ruleTestResult.removeAll()
        }
    }
    func updateRuleResult(_ result:SFRuleResult) {
        dispatchQueue.async  { [unowned self] in
            var found = false
            var idx = 0
            let count = self.ruleResultDynamic.count
            for i in 0 ..< count {
                let x = self.ruleResultDynamic[i]
                if x.req == result.req {
                    found = true
                    idx = i
                    break
                }
            }
            if found {
                self.ruleResultDynamic.remove(at: idx)
                self.ruleResultDynamic.insert(result, at: idx)
            }else {
                self.ruleResultDynamic.append(result)
            }
            
        }
        
    }
    
    public func recentRequestData() ->Data{
        
        var result:[String:AnyObject] = [:]
        var count:Int = connections.count
        
        var reqs:[AnyObject] = []
        for (_,value) in connections {
            let o = value.reqInfo.respObj()
            //print(o)
            reqs.append(o as AnyObject)
           
        }
        if let p = SKit.proxy {
            let proxyInfos = p.runningRequests()
            count += proxyInfos.count
            for info in proxyInfos {
                let o = info.respObj()
                
                reqs.append(o as AnyObject)
            }
        }
        
        result["count"] = NSNumber.init(value: count)
        result["session"] = SFEnv.session.idenString() as AnyObject?
        result["data"] = reqs as AnyObject?
        let j = JSON(result)
    
        var data:Data
        do {
            try data = j.rawData()
        }catch let error  {
            
            data = error.localizedDescription.data(using: .utf8)!// NSData()
        }
        return data
    }
    func findRuleResult(_ host:String) ->SFRuleResult?{
        // 并行bug?
        for r in ruleResultDynamic {
            if r.req == host {
                return r
            }
        }
        //don't use cache
        return nil
    }
    func addRuleResult(_ r:SFRuleResult)  {
        if ruleTestResult.count > 50 {
            //iOS9 limit
            // concurrent bug
            ruleTestResult.removeLast()
        }
        var found = false
        if r.result.policy == .Reject {
            SKit.alertMessage("\(r.req) \(r.result.name) 已经拦截")
        }
        for x  in ruleTestResult {
            if x.req == r.req {
                found = true
                return
            }
        }
        if found == false {
            ruleTestResult.insert(r, at: 0)
        }
        
    }

    public  func ruleResultData() ->Data{
        
        
        
        var result:[AnyObject] = []
        for x in ruleTestResult {
            let o = x.resp()
            result.append(o as AnyObject)
        }
        let j = JSON(result)
        debugLog("ruleResultData")
        var data:Data
        do {
            try data = j.rawData()
        }catch let error  {
            //SKit.log("ruleResultData error \(error)")
            print(error)
            data = Data()
        }
        return data
    }
    func test()  {
        _ =  recentRequestData()
        _ = ruleResultData()
        
    }
    func shouldReadPacket() ->Bool {
        var bufferCount:Int = 0
        for (_,c) in connections {
            bufferCount += c.sendBufferSize()
        }
        if bufferCount > 1*1024*1024 {
            return false
        }else {
            return true
        }
        
    }
}


