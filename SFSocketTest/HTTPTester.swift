//
//  HTTPTester.swift
//  SFSocket
//
//  Created by 孔祥波 on 02/05/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//

import UIKit
import SFSocket
import Xcon
class HTTPTester: NSObject,XconDelegate {
    func didDisconnect(_ socket: Xcon, error: Error?) {
        
    }
    
    func didReadData(_ data: Data, withTag: Int, from: Xcon) {
        
    }
    
    func didWriteData(_ data: Data?, withTag: Int, from: Xcon) {
        
    }
    
    func didConnect(_ socket: Xcon) {
        
    }
    

    var proxy:SFProxy
    var session:Xcon?
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
//        let data = "HEAD http://baidu.com/ HTTP/1.1\r\nHost: baidu.com\r\nUSER-AGENT: kcptun\r\nAccept: */*\r\nProxy-Connection: Keep-Alive\r\n\r\n".data(using: .utf8)!
//        if let s = session {
//            s.sendData(data, withTag: 0)
//        }
//        print("connected ok")
//
    }
    
 
}
