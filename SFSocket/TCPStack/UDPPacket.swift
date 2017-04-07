//
//  UDPPacket.swift
//  SimpleTunnel
//
//  Created by 孔祥波 on 15/11/2.
//  Copyright © 2015年 Apple Inc. All rights reserved.
//

import Foundation
import NetworkExtension


public  class UDPPacket:NSObject{
    public var sourcePort:UInt16 = 0
    public var destinationPort:UInt16 = 0
    var _rawData:Data
    public init(PacketData:Data){
        //debugLog("UDPPacket init")
        _rawData = PacketData
        var p = Data(_rawData.subdata(in: Range( 0 ..< 2)))
        sourcePort = p.to(type: UInt16.self).byteSwapped
        p = Data(_rawData.subdata(in: Range( 2 ..< 2+2)))
        let dp = p.to(type: UInt16.self)
        //MARM: bug here
        destinationPort = UInt16(dp).byteSwapped
        super.init()
    }
    public func payloadData() -> Data{
        
        let d = Data(_rawData.subdata(in: Range(8 ..< _rawData.count)))
        return d
        
        
    }
    deinit{
        //debugLog("UDPPacket deinit")
    }
}
