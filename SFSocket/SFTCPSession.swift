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
    var sessionID:UInt32 = 0
    var queue:DispatchQueue?
    //MARK: - RawSocketDelegate
    public func didDisconnect(_ socket: RawSocketProtocol,  error:Error?){
        delegate?.didDisconnect(self, error: error)
    }
    init(s:UInt32) {
        sessionID = s
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
        
        
        return "no imp"
    }
    /**
     The socket did read some data.
     
     - parameter data:    The data read from the socket.
     - parameter withTag: The tag given when calling the `readData` method.
     - parameter from:    The socket where the data is read from.
     */
    public func didReadData(_ data: Data, withTag: Int, from: RawSocketProtocol){
        delegate?.didReadData(data, withTag: withTag, from: self)
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
        delegate?.didConnect(self)
    }
    
    //MARK: - Create
    //proxy chain suport flag
   
    //var proxyChain:Bool = false
    static public func socketFromProxy(_ p: SFProxy?,policy:SFPolicy,targetHost:String,Port:UInt16,sID:UInt32,delegate:TCPSessionDelegate,queue:DispatchQueue) ->TCPSession? {
        let s = TCPSession.init(s: sID)
        s.delegate = delegate
        let queue = SFTCPConnectionManager.shared().dispatchQueue
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
                AxLogger.log(message,level: .Trace)
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
                    AxLogger.log(message,level: .Trace)
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
                AxLogger.log(message,level: .Trace)
                if !p.kcptun {
                    switch p.type {
                    case .HTTP,.HTTPS:
                        let connector = HTTPProxyConnector.connectorWithSelectorPolicy(targetHostname: targetHost, targetPort: Port, p: p, delegate: s, queue: queue)
                        let data = SFHTTPRequestHeader.buildCONNECTHead(targetHost, port: String(Port),proxy: p)
                        let message = String.init(format:"http proxy %@ %d", targetHost,Port )
                        AxLogger.log(message,level: .Trace)
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
                        AxLogger.log("Config not support", level: .Error)
                        return nil
                    }
                }else {
                    guard let adapter = Adapter.createAdapter(p, host: targetHost, port: Port) else  {
                        return nil
                    }
                    KCPTunSocket.sharedTunnel.updateProxy(p)
                    KCPTunSocket.sharedTunnel.incomingStream(sID, session: s)
                    s.adapter = adapter
                    s.socket = KCPTunSocket.sharedTunnel //.create(policy, targetHostname: targetHost, targetPort: Port, p: p, sessionID: Int(sID))
                    s.queue = queue
                    
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
        if let t = socket {
            if let adapter = adapter {
                if adapter.isKcp() {
                   let frames = split(data, cmd: cmdPSH, sid: sessionID)
                    for f in frames {
                        
                        t.writeData(f.frameData(), withTag: 0)
                    }
                    if let queue = queue {
                        queue.async {
                            self.delegate?.didWriteData(data, withTag: tag, from: self)
                        }
                    }
                }else {
                    t.writeData(data, withTag: tag)
                }
            }else {
                t.writeData(data, withTag: tag)
            }
            
            
        }
        
    }
    func split(_ data:Data, cmd:UInt8,sid:UInt32) ->[Frame]{
        //let fs = data.count/frameSize + 1
        var result:[Frame] = []
        var left:Int = data.count
        var index:Int = 0
        while left > frameSize {
            let subData = data.subdata(in: index ..< frameSize )
            let f = Frame.init(cmd, sid: sid, data: subData)
            index -= frameSize
            left += frameSize
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
            }//udp don't need read
            
            return
        }
        // UDP don't need read func
    }
    public  func forceDisconnect(){
        if let t = socket{
            t.forceDisconnect(sessionID)
        }
    }
    
    
}
