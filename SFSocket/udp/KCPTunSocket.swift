//
//  KCPTunSocket.swift
//  SFSocket
//
//  Created by 孔祥波 on 22/03/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//
// provide KCP for other layer use
// iOS app can't fork process
// so use socket
import Foundation
import NetworkExtension
import AxLogger
import kcp
//应该是shared
// 可以先不实行adapter，加密,用kun 加密
// 测试先是不加密，aes 加密， adapter 加密
// 重新链接 需要？
enum TunError:Error {
   
    case noHead
    case VerError
    case bodyNotFull
    case internalError
    
}
class KCPTunSocket: RAWUDPSocket ,SFKcpTunDelegate{
    
    //var adapter:Adapter! //ss/socks5/http obfs
    var proxy:SFProxy?
    
    var streams:[UInt32:TCPSession] = [:]
   
    
    
    var tun:SFKcpTun?
    var channels:[Channel] = []
    var config:TunConfig = TunConfig()
    var block:BlockCrypt!
    var smuxConfig:Config = Config()
    var ready:Bool = false
    var readBuffer:Data = Data()
    var dispatchTimer:DispatchSourceTimer?
    var q :DispatchQueue?
    func shutdown(){
        if let t = dispatchTimer {
            t.cancel()
        }
        if let tun = self.tun{
            tun.shutdownUDPSession()
        }
    }
    //tun delegate
    public func connected(_ tun: SFKcpTun!){
        
    }
    
    public func disConnected(_ tun: SFKcpTun!){
        
    }
    
    public func tunError(_ tun: SFKcpTun!, error: Error!){
        
    }
    
    func readFrame() -> (Frame?,TunError?) {
        guard  readBuffer.count >= headerSize else {
            return (nil , TunError.noHead)
        }
        let h = readBuffer.subdata(in: 0 ..< headerSize) as rawHeader
        
        if h.Version() != version {
            return (nil , TunError.VerError)
        }
        
        var frame:Frame = Frame.init(h.cmd(), sid: h.StreamID())
        let length = h.Length()
        if length > 0 {
            if readBuffer.count >= headerSize + length {
                frame.data = readBuffer.subdata(in: headerSize ..< headerSize + length)
                
                //readBuffer.resetBytes(in: 0 ..< headerSize + length)
                readBuffer.replaceSubrange(0 ..< headerSize + length, with: Data())
                return (frame,nil)
            }else {
                //等待
                return (frame, TunError.bodyNotFull)
            }
        }else {
            readBuffer.replaceSubrange(0 ..< headerSize,with:Data())
            return (frame, nil)
        }
        
    }
    public func didRecevied(_ data: Data!){
        self.readBuffer.append(data)
        AxLogger.log("mux recv data:\(data as NSData)",level: .Debug)
        while self.readBuffer.count >= headerSize {
            let r = readFrame()
            if let f = r.0 {
                if f.sid == 0 {
                     AxLogger.log("Nop Event recv", level: .Debug)
                }else {
                    if let stream =  streams[f.sid] {
                        if let d = f.data {
                            stream.didReadData(d, withTag: 0, from: self)
                        }else {
                            if r.1 == TunError.bodyNotFull {
                                AxLogger.log("frame \(f.desc) packet not full",level: .Error)
                                break
                            }
                            
                        }
                        
                    }else {
                       AxLogger.log("frame \(f.desc) not found stream",level: .Error)
                        
                    }

                }
                
            }else {
                AxLogger.log("buffer \(self.readBuffer as NSData) parser error",level: .Debug)
            }
        }
       
        
        
    }
    static var sharedTunnel: KCPTunSocket = KCPTunSocket()
    
    func updateProxy(_ proxy:SFProxy,queue:DispatchQueue){
        
        if ready {
            return
           // fatalError()
        }
        self.proxy = proxy
        let c = createTunConfig( proxy)
        
        self.tun = SFKcpTun.init(config: c, ipaddr: proxy.serverIP, port: Int32(proxy.serverPort)!, queue: queue)
        self.tun?.delegate = self as SFKcpTunDelegate
        self.keepAlive(timeOut: 10);
        self.ready = true
    }
    func keepAlive(timeOut:Int)  {
         q = DispatchQueue(label:"com.yarshure.keepalive")
        let timer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags.init(rawValue: 0), queue:q )
        q?.async{
            let interval: Double = Double(timeOut)
            
            let delay = DispatchTime.now()
            
            timer.scheduleRepeating(deadline: delay, interval: interval, leeway: .nanoseconds(0))
            
            timer.setEventHandler {[unowned self] in
                self.sendNop()
                //self.call(self.dispatch_timer)
            }
            timer.setCancelHandler {
                print("dispatch_timer cancel")
            }
            timer.resume()
            
        }
        self.dispatchTimer = timer
    }
    func sendNop(){
        AxLogger.log("send Nop", level: .Debug)
        let frame = Frame(cmdNOP,sid:0)
        let data = frame.frameData()
        //self.streams[0] = session
        self.writeData(data, withTag: 0)

    }
    func createTunConfig(_ p:SFProxy) ->TunConfig {
        let c = TunConfig()
        
        c.dataShards = Int32(p.config.datashard)
        c.parityShards = Int32(p.config.parityshard)
        //c.nodelay = p.config.
        c.sndwnd = Int32(p.config.sndwnd)
        c.rcvwnd = Int32(p.config.rcvwnd)
        c.mtu = Int32(p.config.mtu)
        c.iptos = Int32(p.config.dscp)
        switch p.config.mode {
            case "normal":
                c.nodelay = 0
                c.interval = 40
                c.resend = 2
                c.nc = 1
            case "fast":
                c.nodelay = 0
                c.interval = 30
                c.resend = 2
                c.nc = 1
            case "fast2":
                c.nodelay = 1
                c.interval = 20
                c.resend = 2
                c.nc = 1
            case "fast3":
                c.nodelay = 1
                c.interval = 10
                c.resend = 2
                c.nc = 1
            default:
                c.nodelay = 0
                c.interval = 30
                c.resend = 2
                c.nc = 1
                break
        }
        if !p.config.crypt.isEmpty {
            c.crypt = p.config.crypt
            if  let d = p.pkbdf2Key() {
                c.key = d
            }
            
            
        }
        AxLogger.log("KCPTUN: #######################", level: .Info)
        AxLogger.log("KCPTUN: Crypto = \(c.crypt)", level: .Info)
        AxLogger.log("KCPTUN: key = \(c.key as NSData)", level: .Debug)

        AxLogger.log("KCPTUN: mode = \(p.config.mode)", level: .Info)
        AxLogger.log("KCPTUN: datashard = \(p.config.datashard)", level: .Info)
        AxLogger.log("KCPTUN: parityshard = \(p.config.parityshard)", level: .Info)
        AxLogger.log("KCPTUN: #######################", level: .Info)
        return c
    }
    //new tcp stream income
    func incomingStream(_ sid:UInt32,session:TCPSession) {
        
        self.streams[sid] = session
        queue.asyncAfter(deadline: .now() + .milliseconds(500)) { 
            session.didConnect(self)
        }
    }
    //when network changed,should call this
    func destoryTun() {
        if let tun = tun {
            tun.shutdownUDPSession()
            ready = false
        }
    }
    //MARK: - socket
    override func socketConnectd(){
        // ss /kcptun don't need shakehand
        //tun ready
        //delegate?.didConnect(self)
        self.ready = true
    }
    
    func readCallback(data: Data?, tag: Int) {
        //sSelf.delegate?.didReadData(data, withTag: 0, from: sSelf)
        //tun.inputDataSocket(data!)
        //callback
    }
    
    public  func writeData(_ data: Data, withTag: Int,channelID:Int) {
        //先经过ss
        // let c:Channel =  channels.filter {$0.cId == channelID }.first!
        //c.send(data)
        
        //let newdata = adapter.send(data)
        // tun.inputDataAdapter(newdata)
        // api
    }
    public override func writeData(_ data: Data, withTag: Int) {
        //先经过ss
        //fatalError()
        //        guard let  adapter = Adapter else { return  }
        //        let newdata = adapter.send(data)
        //        tun.inputDataAdapter(newdata)
        // api
        AxLogger.log("write \(data as NSData)",level: .Debug)
        if let tun = tun {
            tun.input(data)
        }else {
            AxLogger.log("kcptun not ready ", level: .Error)
        }
    }
    func outputCallBackApapter(_ data:Data){
        super.writeData(data, withTag: 0)
    }
    func outputCallBackSocket(_ data:Data){
        delegate?.didReadData(data, withTag: 0, from: self)
    }
    // Remote server need close event?
    //MARK: -- tod close channel
    //only for kcptun
    //close ,remove tcp session
    public override func forceDisconnect(_ sessionID:UInt32){
        AxLogger.log("\(sessionID) forceDisconnect", level: .Debug)
        self.streams.removeValue(forKey: sessionID)
        
        let frame = Frame(cmdFIN,sid:sessionID)
        let data = frame.frameData()
        if let tun = tun {
            tun.input(data)
        }
    }

    /**
     Connect to remote host.
     
     - parameter host:        Remote host.
     - parameter port:        Remote port.
     - parameter enableTLS:   Should TLS be enabled.
     - parameter tlsSettings: The settings of TLS.
     
     - throws: The error occured when connecting to host.
     */
    public override func connectTo(_ host: String, port: UInt16, enableTLS: Bool, tlsSettings: [NSObject : AnyObject]?) throws{
//        guard let udpsession = RawSocketFactory.TunnelProvider?.createUDPSession(to: NWHostEndpoint(hostname: host, port: "\(port)"), from: nil) else {
//            return
//        }
//        
//        session = udpsession
//        session!.addObserver(self, forKeyPath: "state", options: [.initial, .new], context: nil)
//        session!.setReadHandler({ [ weak self ] dataArray, error in
//            guard let sSelf = self else {
//                return
//            }
//            
//            sSelf.updateActivityTimer()
//            
//            guard error == nil else {
//                AxLogger.log("Error when reading from remote server. \(String(describing: error))",level: .Error)
//                return
//            }
//            
//            for data in dataArray! {
//                sSelf.readCallback(data: data, tag: 0)
//                
//            }
//            }, maxDatagrams: 32)
    }
//    
//    static func create(_ selectorPolicy:SFPolicy ,targetHostname hostname:String, targetPort port:UInt16,p:SFProxy,sessionID:Int) ->KCPTunSocket? {
//        //new channel 
//        // channel layer
//        guard let adapter = Adapter.createAdapter(p, host: hostname, port: UInt16(port)) else  {
//            return nil
//        }
//        var c:KCPTunSocket
//        for cc in KCPTunSocket.sharedTuns {
//            if cc.proxy == p {
//                //find 
//                let channel = Channel.init(a: adapter)
//                //MARK: to do create channel?
//                cc.channels.append(channel)
//                return cc
//                
//            }
//        }
//        
//        if let port  = UInt16(p.serverPort){
//            c = KCPTunSocket.init()
//            //c.adapter = adapter
//            c.proxy = p
//            c.smuxConfig.MaxReceiveBuffer = c.config.SockBuf
//            c.smuxConfig.KeepAliveInterval =  UInt64(c.config.KeepAlive) //time.Duration(config.KeepAlive) * time.Second
//            guard let pass = c.config.pkbdf2Key(pass: p.key, salt: "kcp-go".data(using: .utf8)!) else {
//                return nil
//            }
//            c.block =  BlockCrypt.create(type:  p.cryptoType, pass: pass) //(type: p.cryptoType, key: pass)
//            let channel = Channel.init(a: adapter)
//            c.channels.append(channel)
//            KCPTunSocket.sharedTuns.append(c)
//            try! c.connectTo(p.serverAddress, port: port, enableTLS: false, tlsSettings: nil)
//            return c
//        }else {
//            return nil
//        }
//    }
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
//        guard keyPath == "state" else {
//            return
//        }
//        //crash
//        //        if let  e = connection.error {
//        //            AxLogger.log("\(cIDString) error:\(e.localizedDescription)", level: .Error)
//        //        }
//        
//        if object ==  nil  {
//            AxLogger.log("\(cIDString) error:connection error", level: .Error)
//            //return
//        }
//        
//        //guard let connection = object as! NWTCPConnection else {return}
//        //crash
//        guard  let connection = session else {return}
//        
//        switch connection.state {
//        case .ready:
//            queueCall {[weak self] in
//                if let strong = self {
//                    strong.socketConnectd()
//                }
//                
//            }
//        case .failed:
//            
//            queueCall {[weak self] in
//                if let strong = self {
//                    strong.cancel()
//                }
//                
//            }
//        case .cancelled:
//            queueCall {
//                if let delegate = self.delegate{
//                    delegate.didDisconnect(self, error: nil)
//                }
//                
//                //self.delegate = nil
//            }
//        default:
//            break
//            
//            
//        }
//       
//        AxLogger.log("\(cIDString) state: \(connection.state.description)", level: .Debug)
    }

}
