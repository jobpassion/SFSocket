//
//  SFProxySession.swift
//  SFSocket
//
//  Created by 孔祥波 on 29/03/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//

import Foundation
import AxLogger
public class ProxyChain {
    //proxy chain suport flag
    public var proxy:SFProxy? //first proxy, support proxy chain
    
    public static var shared = ProxyChain()
    //var proxyChain:Bool = false
}
public protocol TCPSessionDelegate: class {
    /**
     The socket did disconnect.
     
     This should only be called once in the entire lifetime of a socket. After this is called, the delegate will not receive any other events from that socket and the socket should be released.
     
     - parameter socket: The socket which did disconnect.
     */
    func didDisconnect(_ socket: TCPSession,  error:Error?)
    
    /**
     The socket did read some data.
     
     - parameter data:    The data read from the socket.
     - parameter withTag: The tag given when calling the `readData` method.
     - parameter from:    The socket where the data is read from.
     */
    func didReadData(_ data: Data, withTag: Int, from: TCPSession)
    
    /**
     The socket did send some data.
     
     - parameter data:    The data which have been sent to remote (acknowledged). Note this may not be available since the data may be released to save memory.
     - parameter withTag: The tag given when calling the `writeData` method.
     - parameter from:    The socket where the data is sent out.
     */
    func didWriteData(_ data: Data?, withTag: Int, from: TCPSession)
    
    /**
     The socket did connect to remote.
     
     - parameter socket: The connected socket.
     */
    func didConnect(_ socket: TCPSession)
}
public class TCPSession: RawSocketDelegate {
    // TCP 1:1
    // UDP N:1 , shoud add key for close 
    // UDP one channel
    // 用来处理数据和加解密？
    var adapter:Adapter?
    weak var delegate:TCPSessionDelegate?
    var readPending:Bool = false
    var writePending:Bool = false
    var socket:RawSocketProtocol?//NWTCPSocket?
    var frameSize:Int = 4096 //65535
    var frameZeroTag:Int = 0
    var frameNegoTag:Int = -200
    var sessionID:UInt = 0
    var queue:DispatchQueue?
    var readingTag:Int = 0
    var reading:Bool = false
    
    
    //MARK: - RawSocketDelegate
    public func didDisconnect(_ socket: RawSocketProtocol,  error:Error?){
        
        delegate?.didDisconnect(self, error: error)
    }
    var desc:String {
        return "TCP Session :\(sessionID)"
    }
    init(s:UInt) {
        
        sessionID = s
        SKit.log("Income session:\(sessionID)", level: .Info)
    }
    public var useCell:Bool {
        get {
            if let t = socket {
                return t.useCell
            }
            
            return false
        }
    }
    /// The destination address.
    ///
    /// - note: Always returns `nil`.
    //MARK: - tobe add
    public var destinationIPAddress: String? {
        
        if let adapter = adapter {
            //kcp
            return adapter.proxy.serverAddress
        }else {
            if let socket = socket {
                if let x = socket.destinationIPAddress  {
                    let destip = x.presentation
                    
                    return destip
                }
            }
        }
        
        return "no imp"
    }
    public var sourceIPAddress: String? {
        
        
        if let _ = adapter {
            //kcp
            return Smux.sharedTunnel.localAddress()
        }else {
            if let socket = socket {
                if let x = socket.sourceIPAddress  {
                    let s = x.presentation
                    
                    return s
                }
            }
        }
        return "local"
    }
    /**
     The socket did read some data.
     
     - parameter data:    The data read from the socket.
     - parameter withTag: The tag given when calling the `readData` method.
     - parameter from:    The socket where the data is read from.
     */
    public func didReadData(_ data: Data, withTag: Int, from: RawSocketProtocol){
        //SKit.log(desc + " recv \(data as NSData)", level: .Debug)
        if let adapter = adapter {
            
            do  {
                let  cnnectflag = adapter.streaming
                //var newData = data
//                if adapter.proxy.config.noComp {
//                    //
//                    newData = SnappyHelper.decompress(data)
//                }
                let result = try adapter.recv(data)
                if result.0 {
                    //成功解析返回包，对于ss 是解密成功
                    //SKit.log(desc + " data:\(result.1 as NSData))", level: .Debug)
                    if adapter.proxy.type != .SS {
                        if cnnectflag {
                            //streaming
                            if result.1.count > 0 && readingTag >= 0   {
                                //SKit.log(desc + " shake hand with data",level:.Info)
                                delegate?.didReadData(result.1, withTag: readingTag, from: self)
                            }
                            
                            //SKit.log(desc + " shake hand finished error", level: .Debug)
                        }else {
                            let newcflag = adapter.streaming
                            if cnnectflag != newcflag {
                                SKit.log(desc + " shake hand finished", level: .Debug)
                                //变动第一次才发这个event
                                if let d = delegate {
                                    d.didConnect(self)
                                }else {
                                    SKit.log(desc + " session closed", level: .Debug)
                                    forceDisconnect()
                                }
                                
                            }else {
                               fatalError()
                            }
                        }
                        
                        
                    }else {
                        //ss decrypt ok put date
                        if !result.1.isEmpty {
                            delegate?.didReadData(result.1, withTag: readingTag, from: self)
                        }
                    }
                    
                   
                }else {
                    //send data direct
                    //socks5 proxy 还需要tun
                    SKit.log("recv failure", level: .Error)
                    //self.sendRowData(result.1, withTag: frameNegoTag)
                }
                
            }catch let e {
                SKit.log(desc + "\(e.localizedDescription)", level: .Error)
            }
            
        }else {
            //普通代理模式
            delegate?.didReadData(data, withTag: withTag, from: self)
        }
        
    }
    
    /**
     The socket did send some data.
     
     - parameter data:    The data which have been sent to remote (acknowledged). Note this may not be available since the data may be released to save memory.
     - parameter withTag: The tag given when calling the `writeData` method.
     - parameter from:    The socket where the data is sent out.
     */
    public func didWriteData(_ data: Data?, withTag: Int, from: RawSocketProtocol){
        delegate?.didWriteData(data, withTag: withTag, from: self)
        
    }
    
    /**
     The socket did connect to remote.
     
     - parameter socket: The connected socket.
     */
    public func didConnect(_ socket: RawSocketProtocol) {
        SKit.log(desc + " connected", level: .Debug)
        if let adapter = adapter {
            //send http/socks5 shakehang data ,ss send header data
            self.sendRowData(Data(), withTag: frameZeroTag)
            if adapter.proxy.type == .SS {
                //发生socket 创建消息
                delegate?.didConnect(self)
            }
            
        }else {
            //普通模式
            delegate?.didConnect(self)
        }
        
    }
    
    //MARK: - Create
    //proxy chain suport flag
   
    //var proxyChain:Bool = false
    static public func socketFromProxy(_ p: SFProxy?,policy:SFPolicy,targetHost:String,Port:UInt16,sID:UInt,delegate:TCPSessionDelegate,queue:DispatchQueue) ->TCPSession? {
        let streamID = sID + 3
        let s = TCPSession.init(s: streamID)
        s.delegate = delegate
        
        let proxy = ProxyChain.shared.proxy
        if policy == .Direct {
            //基本上网需求
            guard let chain = proxy else {
                s.socket =  DirectConnector.connectTo(targetHost, port: Port, delegate: s , queue:queue )
                
                return s
            }
            switch chain.type {
            case .HTTP,.HTTPS:
                let connector = HTTPProxyConnector.connectorWithSelectorPolicy(targetHostname: targetHost, targetPort: Port, p: chain,delegate: s , queue:queue)
                let data = SFHTTPRequestHeader.buildCONNECTHead(targetHost, port: String(Port),proxy: chain)
                let message = String.init(format:"http proxy %@ %d", targetHost,Port )
                SKit.log(message,level: .Trace)
                //let c = connector as! HTTPProxyConnector
                connector.reqHeader = SFHTTPRequestHeader(data: data)
                if connector.reqHeader == nil {
                    fatalError("HTTP Request Header nil")
                }
                s.socket = connector
            case .SOCKS5:
                s.socket =  Socks5Connector.connectorWithSelectorPolicy(policy, targetHostname: targetHost, targetPort: Port, p: chain,delegate: s , queue:queue)
                
            default:
                return nil
            }
        }else {
            if let chain = proxy {
                guard let p = p else { return nil}
                guard let adapter = Adapter.createAdapter(p, host: targetHost, port: Port) else  {
                    return nil
                }
                switch chain.type {
                case .HTTP:
                    let connector = CHTTPProxConnector.create(targetHostname: adapter.targetHost, targetPort: adapter.targetPort, p: chain,adapter:adapter, delegate: s, queue: queue)
                    let data = SFHTTPRequestHeader.buildCONNECTHead(adapter.targetHost, port: String(adapter.targetPort),proxy: chain)
                    let message = String.init(format:"http proxy %@ %d", adapter.targetHost,adapter.targetPort )
                    SKit.log(message,level: .Trace)
                    //let c = connector as! HTTPProxyConnector
                    connector.reqHeader = SFHTTPRequestHeader(data: data)
                    if connector.reqHeader == nil {
                        fatalError("HTTP Request Header nil")
                    }
                    
                    s.socket =  connector
                case .SOCKS5:
                    s.socket =   CSocks5Connector.create(policy, targetHostname: adapter.targetHost, targetPort: adapter.targetPort, p: chain,adapter: adapter,delegate: s , queue:queue)
                default:
                    return nil
                }
                
                
                
            }else {
                guard let p = p else { return nil}
                let message = String.init(format:"proxy server %@:%@", p.serverAddress,p.serverPort)
                SKit.log(message,level: .Trace)
                if !p.kcptun {
                    switch p.type {
                    case .HTTP,.HTTPS:
                        let connector = HTTPProxyConnector.connectorWithSelectorPolicy(targetHostname: targetHost, targetPort: Port, p: p, delegate: s, queue: queue)
                        let data = SFHTTPRequestHeader.buildCONNECTHead(targetHost, port: String(Port),proxy: p)
                        let message = String.init(format:"http proxy %@ %d", targetHost,Port )
                        SKit.log(message,level: .Trace)
                        //let c = connector as! HTTPProxyConnector
                        connector.reqHeader = SFHTTPRequestHeader(data: data)
                        if connector.reqHeader == nil {
                            fatalError("HTTP Request Header nil")
                        }
                        s.socket =  connector
                    case .SS:
                        
                        s.socket =    TCPSSConnector.connectTo(targetHost, port: Int(Port), proxy: p, delegate: s, queue: queue)
                        //connectorWithSelectorPolicy(policy, targetHostname: targetHost, targetPort: Port, p: p)
                    case .SS3:
                        s.socket =    TCPSS3Connector.connectorWithSelectorPolicy(policy, targetHostname: targetHost, targetPort: Port, p: p)
                        
                        
                    case .SOCKS5:
                        s.socket =   Socks5Connector.connectorWithSelectorPolicy(policy, targetHostname: targetHost, targetPort: Port, p: p, delegate: s, queue: queue)
                        
                    default:
                        SKit.log("Config not support", level: .Error)
                        return nil
                    }
                }else {
                    guard let adapter = Adapter.createAdapter(p, host: targetHost, port: Port) else  {
                        return nil
                    }
                    SKit.log("TCP incoming :\(streamID)", level: .Debug)
                    s.adapter = adapter
                    s.queue = queue
                    s.socket = Smux.sharedTunnel
                    Smux.sharedTunnel.updateProxy(p,queue: queue)
                    Smux.sharedTunnel.incomingStream(UInt32(streamID), session: s)
                    
                     //.create(policy, targetHostname: targetHost, targetPort: Port, p: p, sessionID: Int(sID))
                    
                    
                }
                
            }
            
        }
        return s
    }
    
    
    //MARK - API
    //kcp use frame input data
    func start(){
        
    }
    public  func sendData(_ data: Data, withTag tag: Int) {
        SKit.log(desc + "send \(data as NSData) \(tag)", level: .Debug)
        if let t = socket {
            if let adapter = adapter {
                
                if adapter.isKcp() {
                    //加密处理 and http / socks5 handshake
                    let newData = adapter.send(data)
//                    if adapter.proxy.config.noComp {
//                        newData = SnappyHelper.compress(newData)
//                    }
                     SKit.log(desc + "adapter  send:data \(newData as NSData) \(tag)", level: .Debug)
                    var databuffer:Data = Data()
                    //基本不可能有0 的情况
                    
//                    if tag == 0 {
//                        let frame = Frame(cmdSYN,sid:sessionID)
//                        let fdata = frame.frameData()
//                        databuffer.append(fdata)
//                        
//                    }
                    
                    
                   let frames = split(newData, cmd: cmdPSH, sid: UInt32(sessionID))
                    for f in frames {
                        databuffer.append(f.frameData())
                        
                    }
                    self.delegate?.didWriteData(data, withTag: tag, from: self)
//                    if adapter.proxy.config.noComp {
//                        let newdatabuffer = SnappyHelper.compress(databuffer)
//                        t.writeData(newdatabuffer, withTag: 0)
//                    }else {
//                       
//                    }
                    
                    t.writeData(databuffer, withTag: 0)
                    
                    
                }else {
                    t.writeData(data, withTag: tag)
                }
            }else {
                t.writeData(data, withTag: tag)
            }
            
            
        }
        
    }
    public  func sendRowData(_ data: Data, withTag tag: Int) {
        SKit.log(desc + " sendraw \(data as NSData) \(tag)", level: .Debug)
        if let info = String.init(data: data, encoding: .utf8) {
            SKit.log(desc + " sendraw " + info, level: .Debug)
        }
        if let t = socket {
            if let adapter = adapter {
                
                if adapter.isKcp() {
                    //
                    //
                    // http/socks5 handshake
                    //多次怎么办？
                    //socks5
                    
                    var databuffer:Data = Data()
                    if tag == frameZeroTag {
                        let frame = Frame(cmdSYN,sid:UInt32(sessionID))
                        let fdata = frame.frameData()
                        databuffer.append(fdata)
                        
                    }
                    
                    let  newData = adapter.send(data)

                    SKit.log(desc + " sendraw new:\(newData as NSData) \(tag)", level: .Debug)
                    let frames = split(newData, cmd: cmdPSH, sid: UInt32(sessionID))
                    for f in frames {
                        databuffer.append(f.frameData())
                        
                    }
//                    if adapter.proxy.config.noComp {
//                        let newdatabuffer = SnappyHelper.compress(databuffer)
//                        t.writeData(newdatabuffer, withTag: 0)
//                    }else {
//                        
//                    }
                    
                    t.writeData(databuffer, withTag: 0)
                    
                }else {
                    t.writeData(data, withTag: tag)
                }
            }else {
                fatalError()
            }
            
            
        }
        
    }
    func split(_ data:Data, cmd:UInt8,sid:UInt32) ->[Frame]{
        //let fs = data.count/frameSize + 1
        var result:[Frame] = []
        var left:Int = data.count
        var index:Int = 0
        while left > frameSize {
            if index >= data.count {
                break
            }
            let subData = data.subdata(in: index ..< frameSize )
            let f = Frame.init(cmd, sid: sid, data: subData)
            index += frameSize
            left -= frameSize
            result.append(f)
        }
        
        if left > 0 {
            let subData = data.subdata(in: index ..< data.count )
            let f = Frame.init(cmd, sid: sid, data: subData)
            result.append(f)
        }
        
        return result
        
    }
    public func  readDataWithTag(_ tag: Int){
        if let t = socket {
            if t.tcp {
                t.readDataWithTag(tag)
            }else {
                //udp don't need read
                if !reading {
                    t.readDataWithTag(tag)
                    return
                }else {
                    //设置正在读
                    t.readDataWithTag(tag)
                    readingTag = tag
                    reading = true
                }
                
                
            }
            return
        }
        // UDP don't need read func
    }
    public  func forceDisconnect(){
        if let t = socket{
            t.forceDisconnect(UInt32(sessionID))
        }
    }
    
    
}
