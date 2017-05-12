//
//  HTTPTester.swift
//  SFSocket
//
//  Created by 孔祥波 on 02/05/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//

import UIKit
import SFSocket
class HTTPTester: NSObject,TCPSessionDelegate {

    var proxy:SFProxy
    var session:TCPSession?
    var queue =  DispatchQueue(label: "com.yarshure.dispatchqueue")
    init(p:SFProxy) {
        self.proxy = p
        super.init()
        
    }
//    -(void)keepAlive{
//    //kcptun need
//    //s.writeFrame(newFrame(cmdNOP, 0))
//    }
    func start(){
        if let s  =  TCPSession.socketFromProxy(proxy, policy: .Proxy, targetHost: "baidu.com", Port: 80, sID: 3, delegate: self, queue: queue){
            self.session = s
        }
        
    }
    
    func didDisconnect(_ socket: TCPSession,  error:Error?){
        
    }
    
    
    func didReadData(_ data: Data, withTag: Int, from: TCPSession)
    {
     
        print("didReadData recv :\(3) \(data as NSData)")
    }
    func didWriteData(_ data: Data?, withTag: Int, from: TCPSession)
    
    {
        
    }
    func didConnect(_ socket: TCPSession){
        let data = "HEAD http://baidu.com/ HTTP/1.1\r\nHost: baidu.com\r\nUSER-AGENT: kcptun\r\nAccept: */*\r\nProxy-Connection: Keep-Alive\r\n\r\n".data(using: .utf8)!
        if let s = session {
            s.sendData(data, withTag: 0)
        }
        print("connected ok")
    }
}
