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
public class TCPSession:RawSocketDelegate {
    
    weak var delegate:TCPSessionDelegate?
    
    var tcp:NWTCPSocket?
    var udp:RAWUDPSocket?
    
    //MARK: - RawSocketDelegate
    public func didDisconnect(_ socket: RawSocketProtocol,  error:Error?){
        delegate?.didDisconnect(self, error: error)
    }
    var useCell:Bool {
        get {
            if let t = tcp {
                return t.useCell
            }
            if let u = udp {
                return u.useCell
            }
            return false
        }
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
    public func socketFromProxy(_ p: SFProxy?,policy:SFPolicy,targetHost:String,Port:UInt16) ->TCPSession? {
        let s = TCPSession()
        let proxy = ProxyChain.shared.proxy
        if policy == .Direct {
            //基本上网需求
            guard let chain = proxy else {
                s.tcp =  DirectConnector.connectorWithHost(targetHost: targetHost, targetPort: Int(Port))
                return s
            }
            switch chain.type {
            case .HTTP,.HTTPS:
                let connector = HTTPProxyConnector.connectorWithSelectorPolicy(targetHostname: targetHost, targetPort: Port, p: chain)
                let data = SFHTTPRequestHeader.buildCONNECTHead(targetHost, port: String(Port),proxy: chain)
                let message = String.init(format:"http proxy %@ %d", targetHost,Port )
                AxLogger.log(message,level: .Trace)
                //let c = connector as! HTTPProxyConnector
                connector.reqHeader = SFHTTPRequestHeader(data: data)
                if connector.reqHeader == nil {
                    fatalError("HTTP Request Header nil")
                }
                s.tcp = connector
            case .SOCKS5:
                s.tcp =  Socks5Connector.connectorWithSelectorPolicy(policy, targetHostname: targetHost, targetPort: Port, p: chain)
                
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
                    let connector = CHTTPProxConnector.create(targetHostname: adapter.targetHost, targetPort: adapter.targetPort, p: chain,adapter:adapter)
                    let data = SFHTTPRequestHeader.buildCONNECTHead(adapter.targetHost, port: String(adapter.targetPort),proxy: chain)
                    let message = String.init(format:"http proxy %@ %d", adapter.targetHost,adapter.targetPort )
                    AxLogger.log(message,level: .Trace)
                    //let c = connector as! HTTPProxyConnector
                    connector.reqHeader = SFHTTPRequestHeader(data: data)
                    if connector.reqHeader == nil {
                        fatalError("HTTP Request Header nil")
                    }
                    
                    s.tcp =  connector
                case .SOCKS5:
                    s.tcp =   CSocks5Connector.create(policy, targetHostname: adapter.targetHost, targetPort: adapter.targetPort, p: chain,adapter: adapter)
                default:
                    return nil
                }
                
                
                
            }else {
                guard let p = p else { return nil}
                let message = String.init(format:"proxy server %@:%@", p.serverAddress,p.serverPort)
                AxLogger.log(message,level: .Trace)
                switch p.type {
                case .HTTP,.HTTPS:
                    let connector = HTTPProxyConnector.connectorWithSelectorPolicy(targetHostname: targetHost, targetPort: Port, p: p)
                    let data = SFHTTPRequestHeader.buildCONNECTHead(targetHost, port: String(Port),proxy: p)
                    let message = String.init(format:"http proxy %@ %d", targetHost,Port )
                    AxLogger.log(message,level: .Trace)
                    //let c = connector as! HTTPProxyConnector
                    connector.reqHeader = SFHTTPRequestHeader(data: data)
                    if connector.reqHeader == nil {
                        fatalError("HTTP Request Header nil")
                    }
                    s.tcp =  connector
                case .SS:
                    if !p.kcptun {
                        s.tcp =    TCPSSConnector.connectorWithSelectorPolicy(policy, targetHostname: targetHost, targetPort: Port, p: p)
                    }else {
                        //tcp udp merge?
                        s.udp = KCPTunSocket.create(policy, targetHostname: targetHost, targetPort: Port, p: p)
                        //fatalError()
                        
                        //return nil
                    }
                    
                case .SS3:
                    s.tcp =    TCPSS3Connector.connectorWithSelectorPolicy(policy, targetHostname: targetHost, targetPort: Port, p: p)
                    
                    
                case .SOCKS5:
                    s.tcp =   Socks5Connector.connectorWithSelectorPolicy(policy, targetHostname: targetHost, targetPort: Port, p: p)
                    
                default:
                    
                    return nil
                }
            }
            
        }
        return s
    }
}
