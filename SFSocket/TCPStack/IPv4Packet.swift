//
//  IPv4Packet.swift
//  SimpleTunnel
//
//  Created by 孔祥波 on 15/11/2.
//  Copyright © 2015年 Apple Inc. All rights reserved.
//

import Foundation
import NetworkExtension


public class IPv4Packet:NSObject{
    public var proto:UInt8 = 0
    public let srcIP:Data
    public let _rawData:Data
    public let destinationIP:Data
    public var headerLength:Int32 = 0
    public let payloadLength:Int32 = 0
    public init(PacketData:Data){
        
        if PacketData.count < 20 {
            //SKit.log("PacketData lenth error",)
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
    public func payloadData() ->Data{
        return Data(_rawData.subdata(in: Range(Int(headerLength) ..< _rawData.count)))
    }
    override open var debugDescription: String {
        return "\(srcIP) \(destinationIP)"
    }
    deinit{
        //debugLog("IPv4Packet deinit")
    }
}
