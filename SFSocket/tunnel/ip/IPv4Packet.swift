//
//  IPv4Packet.swift
//  SimpleTunnel
//
//  Created by 孔祥波 on 15/11/2.
//  Copyright © 2015年  All rights reserved.
//

import Foundation
import NetworkExtension

import XFoundation
public class IPv4Packet:CustomStringConvertible{
    public var proto:UInt8 = 0
    public var ihl:UInt8 = 0
    public let srcIP:Data
    public let _rawData:Data
    public let dstIP:Data
    public var headerLength:Int32 = 0
    public let payloadLength:Int32 = 0
    public init(PacketData:Data){
        if PacketData.count < 20 {
            //SKit.log("PacketData lenth error",)
            fatalError()
        }
        _rawData = PacketData;
        
        var p = Data(_rawData.subdata(in: 0..<1))
        ihl = UInt8(p.to(type: UInt8.self) ^ 0x40)
        p = Data(_rawData.subdata(in:  9 ..< 10))
        proto = p.to(type: UInt8.self)
        srcIP = Data(_rawData.subdata(in: 12 ..< 16))
        //leak
        dstIP = Data(_rawData.subdata(in:  16 ..<  20))
        
        p = Data(_rawData.subdata(in:  0 ..< 1))
        let len = p.data2Int(len: 1) & 0x0F
        headerLength = len * 4
        
       
        
    }
    var srcaddr:String {
        get {
            return srcIP.toIPString()
        }
    }
    var dstaddr:String {
        get {
            return dstIP.toIPString()
        }
    }
    //port
    var sp:UInt16 {
        get {
            if _rawData.count > 20 && ihl == 5{
                return _rawData.dataToInt(s: 20, len: 2).bigEndian
                
            }
            return 0
        }
    }
    //port
    var dp:UInt16 {
        get {
            if _rawData.count > 20 && ihl == 5{
               return _rawData.dataToInt(s: 22, len: 2).bigEndian
                
            }
            return 0
        }
    }
    public func payloadData() ->Data{
        return Data(_rawData.subdata(in: Int(headerLength) ..< _rawData.count))
    }
    open var description: String {
        return "src \(srcIP.toIPString()):\(sp) dst \(dstIP.toIPString()):\(dp))"
    }
    deinit{
        //debugLog("IPv4Packet deinit")
    }
}
