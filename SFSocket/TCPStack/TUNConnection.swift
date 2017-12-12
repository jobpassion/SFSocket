//
//  TUNConnection.swift
//  Surf
//
//  Created by 孔祥波 on 16/2/6.
//  Copyright © 2016年 yarshure. All rights reserved.
//

import Foundation
import Xcon
class TUNConnection: NSObject ,XconDelegate{
    func didDisconnect(_ socket: Xcon, error: Error?) {
        
    }
    
    func didReadData(_ data: Data, withTag: Int, from: Xcon) {
        
    }
    
    func didWriteData(_ data: Data?, withTag: Int, from: Xcon) {
        
    }
    
    func didConnect(_ socket: Xcon) {
        
    }
    
   

    let info:SFIPConnectionInfo
    var forceSend:Bool = false // client maybe close after send, proxy should sending the buffer
    var closeSocketAfterRead:Bool = false // HTTP 
    init(i:SFIPConnectionInfo) {
        info = i
        reqInfo = SFRequestInfo.init(rID: SFConnectionID)
        
        SFConnectionID += 1
        super.init()
    }
    var connector:Xcon?
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
    var sendingTag:Int64 = -1
    
    var forceClose:Bool = false
    var reqInfo:SFRequestInfo
    
    func memoryWarning(_ level:DispatchSource.MemoryPressureEvent){
        
    }
}
