//
//  SFConnection.swift
//  Surf
//
//  Created by yarshure on 15/12/25.
//  Copyright © 2015年 yarshure. All rights reserved.
//

import Foundation
import lwip

import AxLogger
import DarwinCore
//#define ERR_OK          0    /* No error, everything OK. */
//#define ERR_MEM        -1    /* Out of memory error.     */
//#define ERR_BUF        -2    /* Buffer error.            */
//#define ERR_TIMEOUT    -3    /* Timeout.                 */
//#define ERR_RTE        -4    /* Routing problem.         */
//#define ERR_INPROGRESS -5    /* Operation in progress    */
//#define ERR_VAL        -6    /* Illegal value.           */
//#define ERR_WOULDBLOCK -7    /* Operation would block.   */
//#define ERR_USE        -8    /* Address in use.          */
//#define ERR_ISCONN     -9    /* Already connected.       */
//
//#define ERR_IS_FATAL(e) ((e) < ERR_ISCONN)
//
//#define ERR_ABRT       -10   /* Connection aborted.      */
//#define ERR_RST        -11   /* Connection reset.        */
//#define ERR_CLSD       -12   /* Connection closed.       */
//#define ERR_CONN       -13   /* Not connected.           */
//
//#define ERR_ARG        -14   /* Illegal argument.        */
//
//#define ERR_IF         -15   /* Low-level netif error    */
var SFConnectionID:UInt32 = 0
enum ERR_KEY:Int8{
    case ok = 0
    case mem = -1
    case err_BUF = -2
    case err_TIMEOUT = -3
}
let LWIP_ASYNC_TCP_OUT = false
let LWIP_ASYNC_TCP_Recved = false

class SFConnection: TUNConnection ,TCPSessionDelegate,TCPCientDelegate{
    /**
     The socket did disconnect.
     
     This should only be called once in the entire lifetime of a socket. After this is called, the delegate will not receive any other events from that socket and the socket should be released.
     
     - parameter socket: The socket which did disconnect.
     */
    func didDisconnect(_ socket: TCPSession, error: Error?) {
        
    }


    
    public func didSendBufferLen(_ buf_used: Int) {
            SKit.log("didSendBufferLen error", level: .Info)
    }


    typealias  SFPcb =   UnsafeMutablePointer<tcp_pcb>
    var pcb:UnsafeMutablePointer<tcp_pcb> // SFPcb
    
    var reqInfo:SFRequestInfo
    let critLock = NSLock()
    weak var manager:SFTCPConnectionManager?
    var connector:TCPSession?
    var bufArray:[Data] = []
    var bufArrayInfo:[Int64:Int] = [:]
    var socks_recv_bufArray:Data = Data()
    var socks_sendout_length:Int = 0
    var connectorReading:Bool = false
    var pendingConnection:Bool = true
    
    var tag:Int64 = 0
    
    var buf_used:Int = 0
    var rTag:Int = 1 //recv tag?
                     //0 use for handshake and kcp tun use 
    var cIDString:String {
        get {
            #if DEBUG
                return "[" + objectClassString(self) + "-\(reqInfo.reqID)-\(info.tun.port)-\(pcb)" + "]" //self.classSFName()
            #else
                //-\(info.tun.port)-\(pcb)
                return  "[" + objectClassString(self) + "-\(reqInfo.reqID)" + "]" //self.classSFName()
            #endif
        }
    }
    
    var sendingTag:Int64 = -1
    
    var forceClose:Bool = false
   
    //var ipaddr
    func sendBufferSize() -> Int {
        var size:Int = 0
        for d in bufArray {
            size += d.count
        }
        return size
    }
    var idleTimeing:TimeInterval {
        get {
            if reqInfo.socks_up {
                if reqInfo.socks_closed {
                    //why not remover
                    return 9999.0
                }else {
                    if socks_recv_bufArray.count == 0 && bufArray.count == 0  {
                        return reqInfo.idleTimeing
                    }else {
                        return 0.0
                    }
                }
                
            }else {
                return 0.0
            }
            
        }
    }
   
   
    internal init(tcp:SFPcb, host:UInt32,port:UInt16, m:SFTCPConnectionManager){
        pcb = tcp
        
        reqInfo = SFRequestInfo.init(rID: SFConnectionID)
        
        SFConnectionID += 1
        //src == final dest
        var  srcip:UInt32 = pcb.pointee.local_ip.ip4.addr
        var  dstip:UInt32 = pcb.pointee.remote_ip.ip4.addr
        var   sport:UInt16 = pcb.pointee.local_port
        var   dport:UInt16 = pcb.pointee.remote_port
       
        pcbinfo(pcb,&srcip,&dstip, &sport,&dport)
        
        
        let remote_addr  = IPAddr(i: srcip,p: sport)
        let local_addr  = IPAddr(i: dstip, p: dport)
        let info:SFIPConnectionInfo = SFIPConnectionInfo.init(t: local_addr , r:remote_addr )
        manager = m
        
        super.init(i:info)
    }
    deinit {

        SKit.log("\(cIDString) deinit )",level: .Debug)
        //free(pcb)
        SKit.log("Connection-\(reqInfo.reqID) clean", level: .Warning)
        
    }
  
    
    func shouldRemovDeadClient() ->Bool {
        //todo 
        return false
    }
    func checkStatus(){
        if reqInfo.idleTimeing > 15 {
             SKit.log("\(cIDString) idle \(reqInfo.idleTimeing)",level: .Trace)
        }

        
    }
    func socketQueue() ->DispatchQueue{
        return (manager?.socketQueue)!
    }
    
    func delegateQueue() ->DispatchQueue{
        return (manager?.dispatchQueue)!
    }
    func setUpConnector(_ host:String,port:UInt16){
        guard let c = TCPSession.socketFromProxy(reqInfo.proxy, policy: reqInfo.rule.policy, targetHost: host, Port: port, sID: reqInfo.reqID, delegate: self, queue: self.delegateQueue()) else {
            fatalError("")
        }
        connector = c
    }
    func genPolicy(_ dest:String,useragent:String) ->Bool{
        //根据host 产生policy
        //对于TCP 需要反查hostname,
        //http 需要做dns 解析
        //ip 呢？
        
        reqInfo.ruleStartTime = Date() as Date
        var j:SFRuleResult
        SKit.log("\(cIDString) Find Rule For  DEST:   " + dest ,level:  .Debug)
        
        if let r = SFTCPConnectionManager.manager.findRuleResult(dest){
            j = r
            reqInfo.rule = r.result
            findProxy(j,cache: false)
           
        }else {
            
            if let ruler  = SFSettingModule.setting.findRuleByString(dest,useragent:useragent) {
                j = ruler
                
                if !j.ipAddr.isEmpty {
                    reqInfo.remoteIPaddress = j.ipAddr
                }
                reqInfo.rule = ruler.result
                findProxy(j,cache: true)
                
            }else {
                if !reqInfo.remoteIPaddress.isEmpty {
                    findIPRule(reqInfo.remoteIPaddress)
                }else {
                    if SFSettingModule.setting.ipRuleEnable {
                        reqInfo.waitingRule = true
                        SKit.log("async send dns  For  DEST:   " + dest ,level:  .Debug)
                        //findIPaddress()
                        
                        findIPaddressSys(reqInfo.host)
                    }else {
                        SKit.log("\(cIDString) ipRuleEnable disable ,use final rule", level: .Debug)
                        reqInfo.waitingRule = true
                        self.findIPRule("")
                        
                    }
                    
                }
                
            }
            
        }
        
        return !reqInfo.waitingRule
        
  
    }
    
    func findIPaddressSys(_ name:String) {
        let q  = DispatchQueue(label:"com.abigt.dns",attributes:[])
        
        //let hostName = self.reqInfo.host
        q.async{ [weak self] in
            if let strong = self {
                let remoteHostEnt = gethostbyname2((name as NSString).utf8String, AF_INET)
                
                if remoteHostEnt == nil {
                    strong.findIPAddress2()
                }else {
                    let remoteAddr = UnsafeMutableRawPointer(remoteHostEnt?.pointee.h_addr_list[0])
                    
                    var output = [Int8](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                    inet_ntop(AF_INET, remoteAddr, &output, socklen_t(INET6_ADDRSTRLEN))
                    let addr =  NSString(utf8String: output)! as String
                    
                    if let m = strong.manager {
                        let dq = m.dispatchQueue
                        dq.async(execute: {
                            strong.findIPRule(addr)
                        })
                        

                    }else {
                        SKit.log("dispatch queue error",level: .Error)
                    }
                    
                }
            }else {
                SKit.log("weak error",level: .Error)
            }
            

        }


        
    }
    
    func findIPaddress() {
        //这货有bug
        let d = DNSResolver()
        d.hostname = reqInfo.host
        d.querey(reqInfo.host) {[weak self] (record) in
            if let s  = self {
                if record?.type != DNSServiceErrorType.init(0)  {//kDNSServiceErr_NoError
                    SKit.log("DNS request error \(String(describing: record?.type.description)) and send request again",level:.Trace)
                    s.findIPAddress2()
                }else {
                    //
                    //findProxy 跨线程会crash
                    //let q = SFTCPConnectionManager.shared().dispatchQueue
                    let ip = record?.ipaddress
                    //dispatch_async(q) {[weak self] in
                    //    if let strong = self {
                            s.findIPRule(ip!)
                      //  }
                        
                    //}
                }
            }else {
                SKit.log("weak error",level: .Error)
            }
           
        }
    }
    func findIPAddress2() {
        let q  = DispatchQueue(label:"com.abigt.dns")
        let hostName = self.reqInfo.host
        q.async { [weak self] in
            let host = CFHostCreateWithName(nil,hostName as CFString).takeRetainedValue()
            //NSLog("getIPFromDNS %@", hostName)
            //let d = NSDate()
            var result:String?
            CFHostStartInfoResolution(host, .addresses, nil)
            var success: DarwinBoolean = false
            if let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as NSArray?,
                let theAddress = addresses.firstObject as? NSData {
                var hostname = [CChar](repeating: 0, count: Int(256))
                let p = theAddress as Data
                let value = p.withUnsafeBytes { (ptr: UnsafePointer<sockaddr>)  in
                    return ptr
                }
                if getnameinfo(value, socklen_t(theAddress.length),
                               &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                     result = String(cString:hostname)
                    
                }
            }
            if let s = self {
                if let result = result {
                    let queue = s.manager!.dispatchQueue
                    //s.findIPRule(result)
                    queue.async{
                        s.findIPRule(result)
                    }
                }else {
                    SKit.log("\(s.reqInfo.host) dns query failure",level: .Error)
                    let queue = s.manager!.dispatchQueue
                    //s.findIPRule(result)
                    queue.async{
                        s.findIPRule("")
                    }
                    
                    
                }
            }else {
                SKit.log("weak error",level: .Error)
            }
            

        }
        
    }
    func findIPRule(_ ip:String) {
        SKit.log("async request dns back \(self.reqInfo.host):\(ip)",level:.Trace)
        let r  = SFSettingModule.setting.findIPRuler(ip)
        
        let result:SFRuleResult = SFRuleResult.init(request:self.reqInfo.host ,r: r)
        result.ipAddr = ip
        result.result.ipAddress = ip
        if reqInfo.remoteIPaddress != ip {
            reqInfo.remoteIPaddress = ip
        }
        
        self.findProxy(result,cache: !ip.isEmpty)
    }
    func findProxy(_ r:SFRuleResult,cache:Bool) {
        
        SKit.log("\(cIDString) Rule Result \(r.result.proxyName)",level: .Debug)
        reqInfo.findProxy(r,cache: cache)
       
        if !reqInfo.waitingRule {
             SKit.log("\(cIDString) recv rule \(reqInfo.rule.policy), now exit waiting",level: .Warning)
            
            let tim = String(format: cIDString + " rule :%.6f", reqInfo.ruleTiming)
            SKit.log(tim, level: .Info)
            setUpConnector()
        }else {
            SKit.log("\(cIDString) recv rule waiting",level: .Debug)
        }
        
    }
    func memoryWarning(_ level:DispatchSource.MemoryPressureEvent) {
        if reqInfo.waitingRule {
            if reqInfo.ruleTiming > 1 {
                SKit.log("\(reqInfo.host) memoryWarning Wait Rule \(reqInfo.ruleTiming)",level: .Warning)
            }
        }else {
            if reqInfo.socks_up {
                SKit.log("close: \(self.reqInfo.url)",level: .Notify)
                //let e = NSError.init(domain: errDomain, code: -1, userInfo: ["reason":"client_murder"])
                connector?.forceDisconnect()
            }
            
        }
        
    }
    func configConnection(){
//        connector = DirectConnector.connectorWithSelectorPolicy("", targetHostname: local_addr.ipString(), targetPort: local_addr.port)
//        config_tcppcb(pcb, self)
//        connector.manager = self
//
//        connector.start()
    }
    
    func findProxy() {
        
    }
    func configLwip() {
        config_tcppcb(pcb, self)
    }
    func setUpConnector() {
        
    }
    func connection(_ timeout:TimeInterval) {
        
        if reqInfo.rule.policy != .Reject {

            
            reqInfo.sTime = Date() as Date
            if  let s = connector {
                s.delegate = self
                if let manager = manager {
                    s.queue = manager.dispatchQueue
                    //s.socketQueue = manager.socketQueue
                    //s.start()
                }else {
                    SKit.log("TCP Manager error", level: .Error)
                    byebyeRequest()
                }
                
            }else {
                byebyeRequest()
            }
            
            
            //NSLog("################# %@ start ", reqInfo.url)
        }
        
        
    }
    func byebyeRequest() {

        //return
        SKit.log("\(cIDString) byebyeRequest ",level: .Debug)
        reqInfo.closereason = .clientReject
        reqInfo.status = .Complete
        if reqInfo.socks_up == false  {
            //connector not init
            if reqInfo.mode == .HTTP || reqInfo.mode == .HTTPS {
                if let d = http503.data(using: String.Encoding.utf8){
                    if let header  = SFHTTPResponseHeader.init(data: d){
                        reqInfo.respHeader = header
                    }
                    socks_recv_bufArray.append(d)
                    // 有问题sock_up = false
                    client_socks_recv_handler_done(d.count)
                    return
                }
            }else {
                client_free_client()
            }
            
        }else {
            //bug
            if reqInfo.socks_up {
                //reqInfo.socks_closed = true
                //reqInfo.socks_closed = true
                client_free_socks()
            }
        }
        
    }

//    func shutDownRejectconnection(){
//       //SKit.log("\(cIDString) Reject , now close",level: .Info)
//        client_handle_freed_client()
//    }
    internal func client_socks_handler(_ event:SocketEvent){
        //assert(!reqInfo.socks_closed)
        switch event {
            
        case .event_ERROR:
            reqInfo.status = .Complete
            reqInfo.closereason =  .closedError
//            reqInfo.socks_closed = true
//            reqInfo.socks_up = false
            client_free_socks()
        case .event_UP:
            assert(!reqInfo.socks_up)
            reqInfo.status = .Established
            reqInfo.activeTime = Date() as Date
            reqInfo.estTime = Date() as Date
            
            configClient_sent_func(pcb)
//            if !reqInfo.client_closed {
//                
//            }
            reqInfo.socks_up = true
            reqInfo.status = .Transferring
//            if reqInfo.status != .Complete {
//                client_socks_recv_initiate()
//            }
//            client_socks_recv_initiate()
            client_send_to_socks()
//            if (!reqInfo.client_closed) {
//                client_socks_recv_initiate()
//            }

        case .event_ERROR_CLOSED:
            if reqInfo.estTime != reqInfo.sTime{
                //assert(reqInfo.socks_up)
            }
            // reqInfo.socks_up = false
            //reqInfo.status = .Complete
            //reqInfo.socks_closed = true
            reqInfo.socks_closed = true
            client_free_socks()
            break
            
        }
        //debugLog("client_socks_handler")
    }
    
//}
//extension SFConnection {
    
    
//    func connector(connector:Connector , didWriteDataWithTag  _tag:Int64) ->Void{
//       //NSLog("\(cIDString) currrent tag: \(tag) == \(_tag)")
//        if _tag == tag {
//            //let d = bufArray.removeFirst()
//            let len = bufArrayInfo[tag]
//            client_socks_send_handler_done(len!)
//            bufArrayInfo.removeValueForKey(tag)
//            tag += 1
//        } else {
//           //SKit.log("\(cIDString) currrent tag: \(tag) != \(_tag)",level: .Debug)
//        }
//        
//    }
//    func connector(connector:Connector,shouldTimeoutReadWithTag tag: Int, elapsed: NSTimeInterval, bytesDone length: UInt) -> NSTimeInterval
//    {
//        let ts = reqInfo.idleTimeing
//        var timeout:NSTimeInterval = HTTP_CONNECTION_TIMEOUT
//        if reqInfo.mode == .TCP {
//            timeout = TCP_CONNECTION_TIMEOUT
//        }else if reqInfo.mode == .HTTPS{
//            timeout = HTTPS_CONNECTION_TIMEOUT
//        }
//        if reqInfo.status == .Complete {
//            return 0.0
//        }else {
//            
//            if  ts > timeout {
//                //active < 3.0 没读也没写
//                // NSLog("00 ReqID %d ts :%.2f timeout", reqInfo.reqID,ts)
//                debugLog("\(cIDString) time Readnow")
//                return 0.0
//            }else {
//                // 读timeout
//                let x = elapsed + 2.0
//                if x > timeout {
//                    debugLog("\(cIDString) time Readnow")
//                    //NSLog("01 ReqID %d ts :%.2f timeout", reqInfo.reqID,ts)
//                    return 0.0
//                }else {
//                    return x
//                }
//            }
//        }
//        
//    }

 


//extension SFConnection {
    func client_tcp_output() {
        guard let m  = manager else { return }
        if LWIP_ASYNC_TCP_OUT {
            m.dispatchQueue.async {  [unowned self] () -> Void in
                                    //还是会挂掉
                    if !m.tcpOperating {
                        m.tcpOperating = true
                        let err = tcp_output(self.pcb)
                        if err != 0 {
                           //SKit.log("\(self.cIDString) tcp_output error:\(err)",level:.Error)
                            self.client_abort_client()
                            //return -1
                        }
                    }
                    
                    
                
                
            }

            
            
        }else {
            if !m.tcpOperating {
                m.tcpOperating = true
                //have problem
                let err = tcp_output(pcb)
                if err != 0 {
                   //SKit.log("\(cIDString) tcp_output error:\(err)",level: .Error)
                    client_abort_client()
                    //return -1
                }
                m.tcpOperating = false
            }
            

        }
        
    }
    func client_tcp_received(_ len:Int) {
        guard let m = manager else {return}
        if LWIP_ASYNC_TCP_Recved {
            
                m.dispatchQueue.async {  [unowned self]() -> Void in
                    //if let StrongSelf = self {
                        //let err = tcp_output(StrongSelf.pcb)
                        tcp_recved(self.pcb, UInt16(len))
//                        if err != 0 {
//                           //SKit.log("\(StrongSelf.cIDString) tcp_output error:\(err)")
//                            StrongSelf.client_abort_client()
//                            //return -1
//                        }

                    //}
                    
                }
                
            
        }else {
            
            
            if !m.tcpOperating {
                m.tcpOperating = true
                let err = tcp_output(pcb)
                
                if err != 0 {
                   //SKit.log("\(cIDString) tcp_output error",level: .Error)
                    client_abort_client()
                }
                m.tcpOperating = false
                
            }else {
                //SKit.log("\(cIDString) tcp_output error",level: .Error)
            }

            
        }

    }
    func client_socks_recv_initiate(){
        if reqInfo.client_closed {
            client_dealloc()
            return
        }
        assert(!reqInfo.client_closed)
        assert(!reqInfo.socks_closed)
        assert(reqInfo.socks_up)
        guard let c = connector else {return}
        let  _ = SFEnv.SOCKS_RECV_BUF_SIZE
//        if c.mode == .TCP{
//            buf_size = TCP_CLIENT_SOCKS_RECV_BUF_SIZE_UInt
//        }else {
//            buf_size = CLIENT_SOCKS_RECV_BUF_SIZE_UInt
//        }
        if reqInfo.status !=  .RecvWaiting {
            SKit.log("\(cIDString)  reading....",level:.Trace)
            c.readDataWithTag(rTag)
            
        }else {
            SKit.log("\(cIDString)  recv waiting length:\(socks_recv_bufArray.count)",level:.Trace)
            // debugLog("\(cIDString) recv waiting")
        }
        
        
    }
    
    func client_socks_recv_send_out() ->Int{
//        if socks_recv_bufArray.length > 0 && !reqInfo.remoteIPaddress.isEmpty{
//            assert(!reqInfo.client_closed)
//        }
//        if socks_recv_bufArray.length > 0 && (!reqInfo.remoteIPaddress.isEmpty && reqInfo.status != .Complete){
//            assert(!reqInfo.client_closed)
//        }
        
        if reqInfo.rule.policy != .Reject && !reqInfo.remoteIPaddress.isEmpty{
            //assert(reqInfo.socks_up)
        }

        
        var result:Int = 0
        var noBufferAvaliable:Bool = false
        if socks_recv_bufArray.count > 0{
            repeat {
                if socks_recv_bufArray.count == socks_sendout_length{
                    SKit.log("\(cIDString) should tcp_output", level: .Debug)
                    break
                }
                let sndbuf = snd_buf(pcb)
                if sndbuf == 0 {
                    break
                }
                //SKit.log("\(cIDString) lwip check space, buffer:\(socks_recv_bufArray.length) sended:\(socks_sendout_length) sendbuf:\(sndbuf)",level: .Debug)
                let left = socks_recv_bufArray.count - socks_sendout_length
                let to_write = min(left, Int(sndbuf))
                if to_write == 0{
                   
                    noBufferAvaliable = true
                    break
                }
                //will failure here todo fix it
                if tcp_write_check(pcb) <  0  {
                   SKit.log("\(cIDString) lwip write check failure \(reqInfo.url)  will fix ",level: .Debug)
                    //client_abort_client()
                    //return -1
                    break
                }
                //have bug here
                let to = socks_recv_bufArray.subdata(in: Range(socks_sendout_length ..< socks_sendout_length + Int(to_write))) as NSData
                let err = tcp_write(pcb,to.bytes,UInt16(to_write), 0x01)
                
                if err != 0 {
                    if err == -1 {
                       SKit.log("\(cIDString) tcp_write ERR_MEM",level:.Trace)
                       return  -1
                    }
                   //SKit.log("\(cIDString) tcp_write error \(err)",level: .Error)
                    //send
                    if err < -9 {
                        SKit.log("\(cIDString) tcp_pcb error  ",level: .Error)
                        //tcp_recv(pcb,nil)
                        //bug??
                        client_abort_client()
                        SKit.log("\(cIDString) tcp_write write error ",level: .Error)
                       
                        
                        return Int(err)
                    }
                    
                }
                socks_sendout_length += Int(to_write)
                if socks_recv_bufArray.count == socks_sendout_length {
                    break
                }
                //let total = socks_recv_bufArray
                //todo turning performance
               ////SKit.log("\(cIDString) lwip write: \(socks_sendout_length) = \(socks_recv_bufArray.length)",level: .Debug)
                
//                else{
//                   let r = NSMakeRange(Int(to_write),total.length-Int(to_write))
//                   let y = NSData(data: total.subdataWithRange(r))
//                   socks_recv_bufArray.insert(y, atIndex: 0)
//                }
                //err = tcp_output(pcb)
                //SKit.log("\(cIDString) buffer count:\(socks_recv_bufArray.length-socks_sendout_length)",level: .Debug)
//                if err != 0 {
//                   //SKit.log("\(cIDString) tcp_output error",level: .Debug)
//                    client_abort_client()
//                }
                
            }while(socks_recv_bufArray.count > socks_sendout_length)
        }
        //TCP_FASTOPEN
        //不稳定, 下载大文件的时候错误
        //重要raw TCP

//        if let m = manager {
//            dispatch_async(m.dispatchQueue) {  [weak self] () -> Void in
//                if let StrongSelf = self {
//                    let err = tcp_output(StrongSelf.pcb)
//                    
//                    if err != 0 {
//                       //SKit.log("\(StrongSelf.cIDString) tcp_output error:\(err)")
//                        StrongSelf.client_abort_client()
//                        //return -1
//                    }
//                }
//                
//            }
//        }
        
        if let m = manager {
            if !m.tcpOperating {
                m.tcpOperating = true
                if noBufferAvaliable == false {
                    //bug
                    //EXC_BAD_ACCESS
                    //MARK: - todo fixme
                    let err = tcp_output(pcb)
                    
                    if err != 0 {
                        SKit.log("\(cIDString) tcp_output error",level:.Error)
                        client_abort_client()
                        return -1
                    }
 
                }else {
                    SKit.log("\(cIDString) no buffer,now  tcp_output ",level:.Debug)
                    let err = tcp_output(pcb)
                    result = Int(err)
                }
                
                m.tcpOperating = false
                
            }else {
                 SKit.log("\(cIDString) tcpOperating  ",level:.Debug)
            }

        }else {
             SKit.log("\(cIDString) manager nil  ",level:.Debug)
        }
        
        //let len = socks_recv_bufArray.length - socks_sendout_length
        let r = Range(0 ..< socks_sendout_length)
        //memory leak
        socks_recv_bufArray.replaceSubrange(r, with: Data())
        
        //socks_recv_bufArray.replaceBytes(in: r, withBytes: nil, length: 0)
        socks_sendout_length = 0 
//        // more data to queue? todo
//        if (client.socks_recv_buf_sent < client.socks_recv_buf_used) {
//            if (client.socks_recv_tcp_pending == 0) {
//                client_log(client, BLOG_ERROR, "can't queue data, but all data was confirmed !?!");
//                
//                [client client_abort_client];
//                return -1;
//            }
//            
//            client_log(client, BLOG_INFO,"set waiting, continue in client_sent_func");
//            client.socks_recv_waiting = 1;
//            return 0;
//        }
//        
//        // everything was queued
//        client.socks_recv_buf_used = -1;
        return result
    }
    public func client_sent_func(){

        //前 memory leaks
        assert(!reqInfo.client_closed)
        assert(reqInfo.socks_up)
        let len = socks_recv_bufArray.count - socks_sendout_length
        SKit.log("\(cIDString)  client_sent_func \(len) ",level:  .Debug)

        if len == 0 {
            //全copy
            //socks_sendout_length = 0
            //socks_recv_bufArray.length = 0
            if reqInfo.socks_closed  {
                tcp_recv(pcb,nil)
                SKit.log("\(cIDString) client_free_client ", level:  .Debug)
                client_free_client()
                
            }else {
                if forceClose {
                    if let c = connector{
                        if reqInfo.socks_up{
                            SKit.log("\(cIDString) foreceClose \(self.reqInfo.url)",level: .Debug)
                            //c.disconnectWithError(NSError.init(domain: errDomain, code: 0, userInfo: ["reason":"forceClose"]))
                            c.forceDisconnect()
                        }
                        
                    }
                }else {
                    reqInfo.status = .Transferring
                    client_socks_recv_initiate()
                }
                
            }
        }else {
            if reqInfo.status != .Complete {
                reqInfo.status =  .RecvWaiting
            }
            let error = client_socks_recv_send_out()
            if  error < -9 {
                SKit.log("\(cIDString) client_socks_recv_send_out error:\(error)",level: .Error)
                client_abort_client()
                
                //ERR_ABRT
            }else {
               SKit.log("\(cIDString) client_socks_recv_send_out success \(len) ",level: .Debug)
//                if socks_recv_bufArray.length == 0  {
//                    reqInfo.status = .Transferring
//                    client_socks_recv_initiate()
//                }
            }
        }
    }
    func client_socks_recv_handler_done(_ len:Int){
    //    assert(!reqInfo.socks_closed)
//        if reqInfo.rule.policy == .Reject || connector == nil{
//            
//        }
        if connector != nil {
            //assert(reqInfo.socks_up)
        }
        // if client was closed, stop receiving
        
        if len > 0 {
            let slen = client_socks_recv_send_out()
            if  slen < 0 {
               SKit.log("\(cIDString) client_socks_recv_send_out error \(slen)",level: .Error)
            
            }
        }else {
            if reqInfo.status !=  .RecvWaiting{
                client_socks_recv_initiate()
            }else {
                //SKit.log("\(cIDString) status:\(reqInfo.status) ",level: .Debug)
                SKit.log("\(cIDString) status:\(reqInfo.status) waitting",level: .Verbose)
            }
        }
//        if (reqInfo.client_closed) {
//            client_dealloc()
//            return;
//        }
    }
    func client_socks_send_handler_done(_ len:Int){
//        Thread 5 Crashed:: Dispatch queue: com.yarshure.dispatch_queue
//        0   com.yarshure.Surf.TunServerUI 	0x000000010e4d2f57 tcp_output + 103 (tcp_out.c:937)
//        1   com.yarshure.Surf.TunServerUI 	0x000000010e5efab9 _TFC11TunServerUI12SFConnection30client_socks_send_handler_donefSiT_ + 953 (SFConnection.swift:610)
//        2   com.yarshure.Surf.TunServerUI 	0x000000010e51e38f _TTSf4dg_n_n___TFC11TunServerUI13SFHTTPRequest9connectorfTCS_9Connector19didWriteDataWithTagVs5Int64_T_ + 3791 (SFHTTPRequest.swift:122)
//        3   com.yarshure.Surf.TunServerUI 	0x000000010e51ce3e _TToFC11TunServerUI13SFHTTPRequest9connectorfTCS_9Connector19didWriteDataWithTagVs5Int64_T_ + 46
//        4   com.yarshure.Surf.TunServerUI 	0x000000010e586262 _TTSf4dg_n_n___TFC11TunServerUI14TCPSSConnector6socketfTGSQCSo14GCDAsyncSocket_19didWriteDataWithTagSi_T_ + 1058 (TCPSSConnector.swift:222)
//        5   com.yarshure.Surf.TunServerUI 	0x000000010e58393e _TToFC11TunServerUI14TCPSSConnector6socketfTGSQCSo14GCDAsyncSocket_19didWriteDataWithTagSi_T_ + 46
//        6   com.yarshure.Surf.TunServerUI 	0x000000010e4b6fab __38-[GCDAsyncSocket completeCurrentWrite]_block_invoke + 43 (GCDAsyncSocket.m:6174)
//        7   libdispatch.dylib             	0x00007fff908e0871 _dispatch_call_block_and_release + 12
//        8   libdispatch.dylib             	0x00007fff908d533f _dispatch_client_callout + 8
//        9   libdispatch.dylib             	0x00007fff908d9f6f _dispatch_queue_drain + 754
//        10  libdispatch.dylib             	0x00007fff908e063b _dispatch_queue_invoke + 549
//        11  libdispatch.dylib             	0x00007fff908d533f _dispatch_client_callout + 8
//        12  libdispatch.dylib             	0x00007fff908d91cf _dispatch_root_queue_drain + 1890
//        13  libdispatch.dylib             	0x00007fff908d8a34 _dispatch_worker_thread3 + 91
//        14  libsystem_pthread.dylib       	0x00007fff8c9f668f _pthread_wqthread + 1129
//        15  libsystem_pthread.dylib       	0x00007fff8c9f4365 start_wqthread + 13

        //which thread? not stable, maybe EXC_BAD_ACCESS
        assert(!reqInfo.socks_closed)
        assert(reqInfo.socks_up)
        if reqInfo.status == .Complete || reqInfo.status == .Closing {
            client_free_socks()
        }else {
            if !reqInfo.client_closed {
                //tcp_async_recved(len)
                //这里不能异步啊
                // 这里会挂掉吗？ 如果挂掉就要好好计算这个数值了
                tcp_recved(pcb, UInt16(len))
                //client_tcp_received(len)
                client_send_to_socks()
            }
            
        }
        if reqInfo.client_closed {
            client_free_socks()
        }
        
    }
    func incomingData(_ d:Data,len:Int){
        
        bufArray.append(d)
    }

    func client_free_socks(){
        SKit.log( "\(cIDString) \(reqInfo.url) + \(reqInfo.closereason.description)  client_free_socks maybe crash",level: .Verbose)
        //assert(!reqInfo.socks_closed)
        //可能是网络错误或者结束，或者lwip 链接结束了
        //这里比较复杂，导致connection 不被释放
       
        //let msg = "\(cIDString) Close:\(forceClose) sendbuf:\(bufArray.count) recvbuf:\(bufArray.count) c:\(connector) s:\(connector?.socket)"
       //SKit.log(msg,level: .Debug)
        
        //NSLog(msg)
        if reqInfo.socks_up {
            // stop receiving from client
            if (!reqInfo.client_closed) {
                tcp_recv(pcb, nil);
            }
            
            
        }
        if reqInfo.socks_closed {
            tcp_recv(pcb, nil)
        }
        if let _ = connector {
            if  reqInfo.status != .Complete {
                if reqInfo.socks_up && reqInfo.socks_closed == false {
                    let e = NSError.init(domain: "com.yarshure.surf", code: 0, userInfo: ["reason":"client_free_socks"])
                    self.connector!.delegate = nil
                    SKit.log("\(e.localizedDescription) \(self.reqInfo.url)",level: .Verbose)
                    //reqInfo.status = .Complete
                    //self.connector!.disconnectWithError(e)
                    self.connector!.forceDisconnect()
                }
                
                
            }
        }
        
        
        
        
        if socks_recv_bufArray.count > 0 {
            SKit.log("\(cIDString) need send data to lwip length:\(socks_recv_bufArray.count)",level:.Trace)
            //bug
            // lwip还有数据没发送完socket就断开了
            //let status =  TCPPcbWrap.pcbStatus(pcb)
            client_socks_recv_handler_done(socks_recv_bufArray.count)
            
//            
//            if status == tcp_state.init(rawValue: 4) {
//                if client_socks_recv_send_out() < 0 {
//                    socks_recv_bufArray.length == 0
//                    client_abort_client()
//                    
//                }
//
//            }else {
//                socks_recv_bufArray.length == 0
//                client_abort_client()
//            }
//            
        }else {
            //            tcp_recv(pcb, nil);
            //reqInfo.socks_closed = true
            SKit.log("\(cIDString) 1048 client_free_client ",level: .Debug)
            //
            if reqInfo.client_closed {
                client_dealloc()
            }else {
                client_free_client()
            }
            //reqInfo.client_closed = true
            
        }
        
    }
 
    func client_dealloc() {
        assert(reqInfo.client_closed)
        //assert(reqInfo.socks_closed)
    
        if connector != nil {
//            if c.socks_reading {
//                SKit.log("client_dealloc reading" + cIDString,level: .Warning)
//            }
//            if c.socks_writing {
//                SKit.log("client_dealloc writing" + cIDString,level: .Warning)
//            }
        }
        SKit.log("client_dealloc " + cIDString,level: .Verbose)
        reqInfo.eTime = Date()
        
        if let m = manager {
            m.removeConnectionRef(self)
        }else {
            SKit.log("manager error manager = nil",level: .Error)
        }
        
    }

    func client_send_to_socks(){
        //debugLog("client_send_to_socks")
        assert(!reqInfo.socks_closed)
        assert(reqInfo.socks_up)
        let st = (reqInfo.status == .Established) || (reqInfo.status == .Transferring)
        if  st && !bufArray.isEmpty{
            //SKit.log("\(cIDString) sending buffer count \(bufArray.count)",level: .Debug)
            var sendData:Data = bufArray.first!
            for x in bufArray.dropFirst() {
                sendData.append(x)
            }
            
            
            if tag == sendingTag {
                return
            }
            guard let connector = connector  else {return }
            //SKit.log("\(cIDString) writing to Host:\(h):\(p) tag:\(tag)   length \(d.length)",level: .Trace)
            //NSLog("%@ will send data tag:%d", reqInfo.url,tag)
            bufArray.removeAll()
            bufArrayInfo[tag] = sendData.count
            sendingTag = tag
            connector.sendData(sendData, withTag: Int(tag))
            
            
        }
    }
//    func shaduleCheckTask(ts:NSTimeInterval) {
//        if reqInfo.status == .Complete {
//            if let c = connector {
//                c.disconnectWithError(NSError.init(domain: "com.abigt.tcp", code: 1, userInfo: ["reason":"Close"]))
//            }else {
//                client_handle_freed_client()
//                
//            }
//        }else {
//            
//            if  ts > TCP_CONNECTIPN_TIMEPUT {
//               //SKit.log("\(reqInfo.url) not active 30s !!!!",level:.Warning)
//                if let c = connector {
//                    c.disconnectWithError(NSError.init(domain: "com.abigt.tcp", code: 1, userInfo: ["reason":"Close"]))
//                }else {
//                    client_handle_freed_client()
//                    //client_dealloc()
//                }
//            } else {
//                //SKit.log(msg)
//                
//            }
//        }
//    }
    func client_handle_freed_client(){
        //from client_err_func
        //assert(!reqInfo.client_closed)
        
        if reqInfo.client_closed{
            reqInfo.status = .Complete
            SKit.log("\(cIDString) 1009 client_handle_freed_client",level: .Debug)
            client_dealloc()
            return
        }
        
        reqInfo.client_closed = true
        
       
        
        if connector == nil {
            reqInfo.socks_up = false
        }
        if socks_recv_bufArray.count > 0 && reqInfo.status != .Complete{
           SKit.log("\(cIDString) waiting untill buffered data is sent to remote server",level: .Warning)
        }else {
            
            if (!reqInfo.socks_closed)  && reqInfo.socks_up{
                
                
                reqInfo.status = .Complete
                client_free_socks()
            } else {
                reqInfo.status = .Complete
                SKit.log("\(cIDString) 1158 client_handle_freed_client",level: .Debug)
                client_dealloc()
            }

        }
        
        
    }
    func pcbStatusString() -> String {
       return String.init(cString:  pcbStatus(pcb))

    }
    func client_abort_client(){
        //assert(!reqInfo.client_closed)
        SKit.log("\(reqInfo.host) client_abort_client",level: .Debug)
        close_lwip_pcb(true)
        
        client_handle_freed_client()
    }
    func client_free_client(){
        //lwip socket close 关闭入口1
        //ASSERT(!client.client_closed)
        
        //SKit.log(" \(tcp_debug_state_str(status)",)
        SKit.log("\(cIDString) 1146  client_free_client",level: .Debug)
        //debugLog(cIDString)
       //SKit.log("\(cIDString) PCB:\(pcbStatus())", level:.Trace)
                        //client_log(client, BLOG_INFO, "client_free_client");
        close_lwip_pcb(false)
        client_handle_freed_client()
        
    }
    
    
    func close_lwip_pcb(_ abort:Bool) {
        let status =  pcbStat(pcb)
       //SKit.log("\(cIDString) close_lwip_pcb \(pcbStatus()) abort:\(abort)",level: .Debug)

        if reqInfo.client_closed != true  {
//            if socks_recv_bufArray.length > 0 {
//               //SKit.log("\(cIDString) need send data to lwip ,closeTCP",level:  .Debug)
//                client_socks_recv_send_out()
//                return
//            }
            tcp_arg(pcb, nil)
            tcp_err(pcb, nil)
            tcp_recv(pcb,nil)
            tcp_sent(pcb, nil)
            
            // free pcb
            //here have bug  : pointer being freed was not allocated
            //*** set a breakpoint in malloc_error_break to debug
            //if status != tcp_state.init(rawValue: 10)
            
            if status.rawValue != 0  && status.rawValue <= 10{
                
                if abort {
                    SKit.log("\(cIDString) tcp_about pcb",level:  .Debug)
                    tcp_abort(pcb);
                }else {
                   // tcp_abort(pcb);
                    let err :err_t = tcp_close(pcb)//tcp_shutdown(pcb,1,1)//;
                    if (err != 0) {
                        //client_log(client, BLOG_INFO, "tcp_close failed (%d)", err);
                        SKit.log("\(cIDString) tcp_about pcb",level:  .Debug)
                        //tcp_abort(pcb);
                    }else {
                         SKit.log("\(cIDString) tcp_closed pcb",level:  .Debug)
                    }
                }
            }
            reqInfo.client_closed = true
            
        }else {
            SKit.log("\(cIDString) have client_closed",level: .Debug)
        }
        
        //let status =  TCPPcbWrap.pcbStatus(pcb)
       //

    }
    func client_murder() {
        
        close_lwip_pcb(false)
        reqInfo.client_closed = true
        if reqInfo.status != .Complete {
            if let c = connector {
                if reqInfo.socks_up {
                    SKit.log("murder \(self.reqInfo.url)",level: .Notify)
                    //c.disconnectWithError(NSError.init(domain: errDomain, code: -1, userInfo: ["reason":"client_murder"]))
                    c.delegate = nil
                    c.forceDisconnect()
                    //c.disconnect()
                }
                

            }
            reqInfo.status = .Complete
        }else {
            SKit.log("\(cIDString) Complete clearn up",level: .Notify)
        }
    }
    
    //delegate func
    func didDisconnect(_ socket: TCPSession){
        SKit.log("\(cIDString) socket didDisconnect", level: .Debug)
        
        
        if reqInfo.status == .Complete {
            if let m = manager{
                
                m.removeConnectionRef(self)
            }
        }else {
            
            let code = 4
            if let x = SFConnectionCompleteReason(rawValue:code){
                reqInfo.closereason = x
            }else {
                reqInfo.closereason = .otherError
            }
            
            
            connector!.delegate = nil
            
            //reqInfo.socks_up = false
            //reqInfo.status = .Complete
            client_socks_handler(.event_ERROR_CLOSED)
        }
    }
    func didReadData(_ data: Data, withTag: Int, from: TCPSession){
        SKit.log("\(cIDString) socket didReadData", level: .Debug)
        if socks_recv_bufArray.count != 0{
            fatalError()
        }
        socks_recv_bufArray.append(data)
        client_socks_recv_handler_done(data.count)

    }
    func didWriteData(_ data: Data?, withTag: Int, from: TCPSession){
        SKit.log("\(cIDString) socket didWriteData \(tag)", level: .Debug)
        if self.tag == tag {
            //let d = bufArray.removeFirst()
            let len = bufArrayInfo[tag]
            client_socks_send_handler_done(len!)
            bufArrayInfo.removeValue(forKey: tag)
            tag += 1
        } else {
            SKit.log("\(cIDString) currrent tag: \(tag) != \(self.tag)",level: .Debug)
        }
    }
    func didConnect(_ socket: TCPSession){
        SKit.log("\(cIDString) Connect OK with Socket", level: .Info)
        //SKit.log("\(cIDString)  host:\(connector.targetHost) port:\(connector.targetPort) ESTABLISHED",level: .Verbose)
        
        
        reqInfo.interfaceCell  = socket.useCell ? 1: 0
        //MARK: fixme
        reqInfo.localIPaddress = socket.sourceIPAddress!
        reqInfo.remoteIPaddress = socket.destinationIPAddress!
        SKit.log("\(reqInfo.url) routing \(reqInfo.interfaceCell)",level: .Trace)
        client_socks_handler(.event_UP)
    }
    func connectorDidSetupFailed(_ connector:TCPSession, withError:NSError){
        
        SKit.log("\(cIDString)socket DidDisconnect:\((withError))",level: .Error)
        
        
        client_socks_handler(.event_ERROR)
    }
    
}
