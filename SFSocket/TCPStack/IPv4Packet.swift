//
//  IPv4Packet.swift
//  SimpleTunnel
//
//  Created by 孔祥波 on 15/11/2.
//  Copyright © 2015年 Apple Inc. All rights reserved.
//

import Foundation
import NetworkExtension


open class IPv4Packet:NSObject{
    var proto:UInt8 = 0
    let srcIP:Data
    let _rawData:Data
    let destinationIP:Data
    var headerLength:Int32 = 0
    let payloadLength:Int32 = 0
    init(PacketData:Data){
        
        if PacketData.count < 20 {
            //AxLogger.log("PacketData lenth error",)
            fatalError()
        }
        _rawData = PacketData;
        
        
        var p = Data(_rawData.subdata(in: Range( 9 ..< 10)))
        proto = p.to(type: UInt8.self)
        srcIP = Data(_rawData.subdata(in: Range(12 ..< 16)))
        //leak
        destinationIP = Data(_rawData.subdata(in: Range( 16 ..<  20)))
        
        p = Data(_rawData.subdata(in: Range( 0 ..< 1)))
        let len = data2Int(p, len: 1) & 0x0F
        headerLength = len * 4
        
        super.init()
        
    }
    func payloadData() ->Data{
        return Data(_rawData.subdata(in: Range(Int(headerLength) ..< _rawData.count)))
    }
    override open var debugDescription: String {
        return "\(srcIP) \(destinationIP)"
    }
    deinit{
        //debugLog("IPv4Packet deinit")
    }
}