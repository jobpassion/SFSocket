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
class LWIPTraffic {
    var sport:UInt16 = 0
    var lwipInputSpeed:UInt = 0
    var lwipInputTime:Date = Date()
    var lwipDrop:Bool = false
    func updateLwipInput(_ c:UInt) {
        if c > 0 {
            let now = Date()
            let ts = now.timeIntervalSince(lwipInputTime as Date)
            let msec = UInt(ts*100000) //ms
            if msec == 0 {
                lwipInputSpeed = c
            }else {
                lwipInputSpeed = c / msec
            }
            //NSLog("#############%d,%d",msec,lwipInputSpeed)
            
            if lwipInputSpeed > SKit.LimitLWIPInputSpeedSimgle {
                //NSLog("############# speed too fast")
                lwipDrop = true
            }else {
                let memoryUsed = reportMemoryUsed()
                if memoryUsed > UInt64(SKit.memoryLimitUesedSize) * UInt64(SKit.physicalMemorySize*6 + 3) {
                    #if os(iOS)
                        if checkJB() {
                            lwipDrop = false
                        }else {
                            lwipDrop = true
                        }
                        
                        
                    #else
                        lwipDrop = false
                    #endif
                }else {
                    lwipDrop = false
                }
                
            }
            //            #if DEBUG
            //           //SKit.log("\(url) speed: \(msec)/\(recvSpped) ms \n",level:.Trace)
            //            #endif
            lwipInputTime = now
        }
        
    }
}

public class SFTCPConnectionManager:NSObject,TCPStackDelegate {
    open func lwipInitFinish() {
        lwip_init_finished = true
    }
    var clientTree:AVLTree = AVLTree<Int32,GCDTunnelConnection>()
    public static let manager:SFTCPConnectionManager = SFTCPConnectionManager()
    
    internal static func shared() -> SFTCPConnectionManager{
        return manager
    }
    
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
    //private var timer:NSTimer?
    var firsttime = true
    var once : Bool = false
    var networkingScheduledTask :DispatchWorkItem =  DispatchWorkItem.init {
        
    }
    var lwipInputSpeed : [UInt16:LWIPTraffic] = [:]
    
    override init() {
        //var token: dispatch_once_t = 0
        
        //start()
        
        //        dispatch_async(dispatchQueue) { [unowned self] () -> Void in
        //            //reopen()
        //            init_lwip()//lwip_init
        //
        //        }
        //let highPriorityAttr:dispatch_queue_attr_t = dispatch_queue_attr_make_with_qos_class (DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE,-1);
        dispatchQueue = DispatchQueue(label: "com.yarshure.dispatchqueue")
        //let lowPriorityAttr:dispatch_queue_attr_t = dispatch_queue_attr_make_with_qos_class (DISPATCH_QUEUE_SERIAL, QOS_CLASS_BACKGROUND,-1);
        socketQueue =  DispatchQueue(label:"com.yarshure.socketqueue")
        super.init()
        setupStack(self)
        //dispatch_once(&token) {
        
        
        self.installMemoryWarning()
        //}
    }
    //    func addSocketConnection(s:SFHTTPSocketConnection) {
    //        socketConnection.append(s)
    //    }
    public func start(){
        
        //init in other thread , lwip may not init finished
        
        
        
        
        //         dispatch_once(&token) {
        //            init_lwip()
        //        }
        
        
        //DispatchWorkItem(flags: .assignCurrentContext)
        networkingScheduledTask = DispatchWorkItem.init(block: { [unowned self] () ->(Void) in
            //print("************** \(NSDate()) ***********")
            //networkingScheduledTask()
            //
            if !self.tcpOperating{
                //self.checkConnectionStatus()
                self.tcpOperating = true
                tcp_tmr()
                
                self.tcpOperating = false
            }
            
        })
        
        //#if TIMER
        self.startWithInterval(SKit.lwip_timer_second)
        //#endif
        //timer = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: "tcp_timer_handler:", userInfo: nil, repeats: true)
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
    func saveConnectionInfo(_ ref:SFConnection) {
        if ProxyGroupSettings.share.historyEnable {
            //broken
            let helper = RequestHelper.shared
            let info = ref.reqInfo
            helper.saveReqInfo(info)
            // one connection only have a request info
            // http keep-alive finish one will save one
            //            if let s = ref as? SFHTTPConnection{
            //                for req in s.requests{
            //                    helper.saveReqInfo(req)
            //                }
            //            }
        }
    }
    func removeConnectionRef(_ ref:SFConnection){
        //ref.manager = nil
        //connections.remo
        //SKit.log("removeConnectionRef \(ref.cIDString) left:\(connections.count-1)",level: .Debug)
        let sport  = ref.info.tun.port
        
        saveConnectionInfo(ref)
        connections.removeValue(forKey: sport)
        lwipInputSpeed.removeValue(forKey: sport)
        //connections.removeObjectForKey(ref.reqInfo.reqID)
        //abort()
        //test()
    }
    
    public func writeDatagrams(_ data:Data){
        
        DispatchQueue.main.async(execute:{[unowned self] in
            if let p = self.provider {
                p.writeDatagrams(packets: data,proto: AF_INET)
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
        SKit.log("\(srcip.pointee) \(dstip.pointee) \(sport.pointee) \(dport.pointee) incomming tcp", level: .Info)
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
    func tcp_timer_handler(_ t:Timer){
        self.dispatchQueue.async {[weak self] () -> Void in
            //tcp_tmr();
            _ = self!.networkingScheduledTask
        }
        
    }
    public func cleanConnection() {
        SKit.log("[SFTCPConnectionManager] Connection :\(connections.count)",level: .Notify)
        //self.cancel()
        dispatchQueue.async { [unowned self] in
            self.closeAllConnection()
            Smux.sharedTunnel.shutdown()
            self.ruleTestResult.removeAll()
            self.lwipInputSpeed.removeAll()
            SKit.log("[SFTCPConnectionManager] Connection clean Done!",level: .Notify)
        }
        //
        //        closeTW()
    }
    
    public func cancel() {
        //        if self.dispatch_timer != nil {
        //            dispatch_source_cancel(dispatch_timer)
        //        }
        SKit.log("should cancel timer", level: .Debug)
    }
    public func resume() {
        startWithInterval(SKit.lwip_timer_second)
    }
    func startWithInterval(_ interval:Double) {
        self.firsttime = true
        self.cancel()
        self.dispatch_timer =  DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags.init(rawValue: 0), queue: SFTCPConnectionManager.manager.dispatchQueue)
        
        
        let interval: Double = 1.0
        
        let delay = DispatchTime.now()
        
        dispatch_timer.schedule(deadline: delay, repeating: interval, leeway: .nanoseconds(0))
        
        dispatch_timer.setEventHandler { [unowned self] in
            if self.firsttime {
                self.firsttime = false
                return
            }
            _ = self.networkingScheduledTask
            if self.once {
                self.cancel()
            }
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
                
                
                for (packet) in ps {
                    //autoreleasepool {
                    //have bug
                        inputData(packet,packet.count)
                    //}
                }
                _ = strongSelf.networkingScheduledTask
                
                
                strongSelf.checkConnectionStatus()
            }
            let d2 = Date().timeIntervalSince(d1)
            if d2 > 1.0 {
                let m = String.init(format: "device_read_handler_sendPackets %.2f" ,d2)
                SKit.log(m,level: .Warning)
            }
            
            DispatchQueue.global().async {
                complete(nil)
            }
            
        }
    }
    
    
    func device_read_handler_sendPackets(_ unused:UnsafeRawPointer,packets:[Data]){
        //网络切换的时候不会crash
        //debugLog("device_read_handler_sendPackets")
        if lwip_init_finished == false {
            //init not finish ,input packet will
            //drop the packet
            //SKit.log("lwip init not finish drop packet \(data)",level: .Info)
            SKit.log("lwip_init_finished false",level: .Error)
            return
        }
        dispatchQueue.async { [weak self] () -> Void in
            let d1 = Date()
            let ps = packets
            if let strongSelf = self {
                for (_,c) in strongSelf.connections {
                    if c.shouldRemovDeadClient() {
                        strongSelf.removeConnectionRef(c)
                    }
                }
                
                
                for (packet) in ps {
                    
                    inputData(packet as Data!,packet.count)
                }
                _ = strongSelf.networkingScheduledTask
                
            }
            let _ = Date().timeIntervalSince(d1)
            //debugLog("device_read_handler_sendPackets \(d2)")
            
            
            
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
    func device_read_handler_send(_ unused:UnsafeRawPointer,data:Data,len:Int,sport:UInt16){
        //网络切换的时候不会crash
        if lwip_init_finished == false {
            //init not finish ,input packet will
            //drop the packet
            //SKit.log("lwip init not finish drop packet \(data)",level: .Info)
            return
        }
        
    }
    
    
    
    
    public func recentRequestData() ->Data{
        
        //return NSData()
        //memory issue
        
        var result:[String:AnyObject] = [:]
        let count:Int = connections.count
        
        var reqs:[AnyObject] = []
        for (_,value) in connections {
            let o = value.reqInfo.respObj()
            //print(o)
            reqs.append(o as AnyObject)
            //            if let s = value as? SFHTTPConnection{
            //                count += s.requests.count
            //                for req in s.requests{
            //                    let o2 = req.respObj()
            //                    reqs.append(o2)
            //                }
            //            }
        }
        result["count"] = NSNumber.init(value: count)
        result["session"] = SFEnv.session.idenString() as AnyObject?
        result["data"] = reqs as AnyObject?
        let j = JSON(result)
        
        
        debugLog("recentRequestData")
        var data:Data
        do {
            try data = j.rawData()
        }catch let error  {
            //SKit.log("ruleResultData error \(error.localizedDescription)")
            //let x = error.localizedDescription
            data = error.localizedDescription.data(using: .utf8)!// NSData()
        }
        return data
    }
    func findRuleResult(_ host:String) ->SFRuleResult?{
        //key:value
        //        #if DEBUG
        //        return nil
        //        #endif
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
    //    func stat() -> NSData {
    //        let data = NSData()
    //        return data
    //    }
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

//udp protocol manage
extension SFTCPConnectionManager {
    func process_device_udp_packet (_ data:Data, data_len:Int,p:NSNumber,info:SFIPConnectionInfo){
        if p.int32Value == AF_INET6 {
            //SKit.log("[SFTCPConnectionManager] receive IPV6 udp packet",level:.Error)
        }else if p.int32Value == AF_INET {
            
        }else {
            //SKit.log("[SFTCPConnectionManager] receive \(p) udp packet",level:.Error)
        }
        //not dns packet
    }
    //    func findConnection(info:SFIPConnectionInfo) ->SFUDPConnection{
    //        for c in udp_connections{
    //            if c.info.equalInfo( info) {
    //                return c
    //            }
    //        }
    //        let pcb = udp_new()
    //        let c = SFUDPConnection.init(p: pcb, host: info.remote.ip, port: info.remote.port)
    //        return c
    //    }
    func configUDP() {
        
    }
    
    
    func incomingUDP(_ udp:SFUPcb) {
        
    }
}
extension SFTCPConnectionManager:ClientDelegate {
    func startProxyServer(){
        #if os(iOS)
//            let dispatchQueue = DispatchQueue(label:"com.yarshure.httpproxy");
//            dispatchQueue.async {
//                startserver(0)
//            }
        #endif
    }
    
    func clientDead(c:GCDHTTPConnection){
        let fd = c.fd
        close(fd)
        
        
    }
    
    public func startGCDServer(){
        
        if let server = GCDSocketServer.shared(){
            server.accept = { fd,addr,port in
                let c = GCDTunnelConnection.init(sfd: fd, rip: addr!, rport: UInt16(port), dip: "127.0.0.1", dport: 10081)
                
                self.clientTree.insert(key: fd, payload: c)
                //c.connect()
                print("\(fd) \(String(describing: addr)) \(port)")
            }
            server.colse = { fd in
                print("\(fd) close")
                //self.clientTree.delete(key: fd)
                if let c = self.clientTree.search(input: fd){
                    c.forceCloseRemote()
                    self.clientTree.delete(key: fd)
                }
            }
            server.incoming  = { fd ,data in
                print("\(fd) \(String(describing: data))")
                
                if let c = self.clientTree.search(input: fd){
                    c.incommingData(data!,len:data!.count)
                }
                //server.server_write_request(fd, buffer: "wello come\n", total: 11);
            }
            //let q = DispatchQueue.init(label: "dispatch queue")
            server.start(10081, queue: DispatchQueue.main)
        }
 
    }
    func saveTunnelConnectionInfo(_ c:GCDTunnelConnection){
        
    }
    
}
