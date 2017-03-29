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
class KCPTunSocket: RAWUDPSocket {
    
    var adapter:Adapter?
    var tun:KCPTun = KCPTun()
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
        let c = KCPTunSocket.init()
        if let port  = Int(p.serverPort){
            guard let adapter = Adapter.createAdapter(p, host: hostname, port: UInt16(port)) else  {
                return nil
            }
            c.adapter = adapter
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
