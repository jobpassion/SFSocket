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
//应该是shared
class KCPTunSocket: RAWUDPSocket {
    
    var adapter:Adapter! //ss/socks5/http obfs
    
    static var sharedTuns :[KCPTunSocket] = [] //多tun 设计
    var tun:KCPTun = KCPTun()
    var channels:[Channel] = []
    var config:TunConfig = TunConfig()
    var block:BlockCrypt!
    var smuxConfig:Config = Config()
    /**
     Connect to remote host.
     
     - parameter host:        Remote host.
     - parameter port:        Remote port.
     - parameter enableTLS:   Should TLS be enabled.
     - parameter tlsSettings: The settings of TLS.
     
     - throws: The error occured when connecting to host.
     */
    public override func connectTo(_ host: String, port: Int, enableTLS: Bool, tlsSettings: [NSObject : AnyObject]?) throws{
        guard let udpsession = RawSocketFactory.TunnelProvider?.createUDPSession(to: NWHostEndpoint(hostname: host, port: "\(port)"), from: nil) else {
            return
        }
        
        session = udpsession
        session!.addObserver(self, forKeyPath: "state", options: [.initial, .new], context: nil)
        session!.setReadHandler({ [ weak self ] dataArray, error in
            guard let sSelf = self else {
                return
            }
            
            sSelf.updateActivityTimer()
            
            guard error == nil else {
                AxLogger.log("Error when reading from remote server. \(String(describing: error))",level: .Error)
                return
            }
            
            for data in dataArray! {
                sSelf.readCallback(data: data, tag: 0)
                
            }
            }, maxDatagrams: 32)
    }
    
    static func create(_ selectorPolicy:SFPolicy ,targetHostname hostname:String, targetPort port:UInt16,p:SFProxy) ->KCPTunSocket? {
        //new channel 
        // channel layer
        guard let adapter = Adapter.createAdapter(p, host: hostname, port: UInt16(port)) else  {
            return nil
        }
        var c:KCPTunSocket
        for cc in KCPTunSocket.sharedTuns {
            if cc.adapter == adapter {
                //find 
                //MARK: to do create channel?
                
                return cc
                
            }
        }
        
        if let port  = Int(p.serverPort){
            c = KCPTunSocket.init()
            c.adapter = adapter
            c.smuxConfig.MaxReceiveBuffer = c.config.SockBuf
            c.smuxConfig.KeepAliveInterval =  UInt64(c.config.KeepAlive) //time.Duration(config.KeepAlive) * time.Second
            let pass = c.config.pkbdf2Key(pass: p.key)
            c.block =  BlockCrypt.init(type: p.cryptoType, key: pass)

            KCPTunSocket.sharedTuns.append(c)
            try! c.connectTo(p.serverAddress, port: port, enableTLS: false, tlsSettings: nil)
            return c
        }else {
            return nil
        }
    }
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        guard keyPath == "state" else {
            return
        }
        //crash
        //        if let  e = connection.error {
        //            AxLogger.log("\(cIDString) error:\(e.localizedDescription)", level: .Error)
        //        }
        
        if object ==  nil  {
            AxLogger.log("\(cIDString) error:connection error", level: .Error)
            //return
        }
        
        //guard let connection = object as! NWTCPConnection else {return}
        //crash
        guard  let connection = session else {return}
        
        switch connection.state {
        case .ready:
            queueCall {[weak self] in
                if let strong = self {
                    strong.socketConnectd()
                }
                
            }
        case .failed:
            
            queueCall {[weak self] in
                if let strong = self {
                    strong.cancel()
                }
                
            }
        case .cancelled:
            queueCall {
                if let delegate = self.delegate{
                    delegate.didDisconnect(self, error: nil)
                }
                
                //self.delegate = nil
            }
        default:
            break
            
            
        }
       
        AxLogger.log("\(cIDString) state: \(connection.state.description)", level: .Debug)
    }
    //MARK: - socket
    override func socketConnectd(){
        // ss /kcptun don't need shakehand
        delegate?.didConnect(self)
    }
    
    func readCallback(data: Data?, tag: Int) {
        //sSelf.delegate?.didReadData(data, withTag: 0, from: sSelf)
        tun.inputDataSocket(data!)
        //callback
    }
    
    public override func writeData(_ data: Data, withTag: Int) {
        //先经过ss
        
        guard let  adapter = adapter else { return  }
        let newdata = adapter.send(data)
        tun.inputDataAdapter(newdata)
     // api
    }
    func outputCallBackApapter(_ data:Data){
        super.writeData(data, withTag: 0)
    }
    func outputCallBackSocket(_ data:Data){
        delegate?.didReadData(data, withTag: 0, from: self)
    }
    
}
