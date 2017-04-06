//
//  OutgoingConnector.swift
//  SimpleTunnel
//
//  Created by 孔祥波 on 15/10/27.
//  Copyright © 2015年 Apple Inc. All rights reserved.
//

import Foundation
//本地读取Packet, 理论没有丢包问题，由应用层解决吧
// 对于UDP IP 层没有重传机制，wireshark 
//使用stream id 表示
public protocol OutgoingConnectorDelegate: class {
    func serverDidQuery(_ targetTunnel: SFUDPConnector, data : Data, close:Bool)
    //func serverDidQuery(targetTunnel: OutgoingConnector, data : NSData)
    func serverDidClose(_ targetTunnel: SFUDPConnector)
    //func tunnelDidSendConfiguration(targetTunnel: Tunnel, configuration: [String: AnyObject])
}

open class SFUDPConnector: NSObject {
    static var UDPRequestCounter:Int = 0
    
    open weak var delegate: OutgoingConnectorDelegate?
    open var identifier:String?
    
    var reqID:Int = 0
    var clientAddress:Data
    var clientPort:UInt16
    var dstAddress:Data
    var dstPort:UInt16
    var connected:Bool = false
    //var waittingQueriesTimeMap:[UInt16:Date] = [:]
    var activeTime:Date = Date()
    var queryIDCounter:UInt16 = 0 //DNS
    var protocol_family:UInt8 = 0 //DNS 17 
    var sendingQueue:[UDPPacket] = []
    //need recv buffer?
    var  idel:TimeInterval {
        get {
            return Date().timeIntervalSince(activeTime)
        }
    }
    func idleTooLong() ->Bool{
        if self.idel > 10.0 {
            return true
        }else {
            return false
        }
    }
    //var dispatchQueue:dispatch_queue_t?
    init(sip:Data, dip:Data,packet:UDPPacket) {
        
        clientPort = packet.sourcePort
        dstPort = packet.destinationPort
        clientAddress = sip
        dstAddress =  dip
        sendingQueue.append(packet)
        
        reqID = SFUDPConnector.UDPRequestCounter
        SFUDPConnector.UDPRequestCounter += 1
        if SFUDPConnector.UDPRequestCounter  == Int.max{
            SFUDPConnector.UDPRequestCounter = 0
        }
        super.init();
    }

    func addQuery(packet p:UDPPacket!) {
    }
}