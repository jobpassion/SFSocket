//
//  SFUitl.swift
//  Surf
//
//  Created by yarshure on 15/12/22.
//  Copyright © 2015年 yarshure. All rights reserved.
//

import Foundation

public enum SFTunnelError: Error {
    case badConfiguration
    case badConnection
    case internalError
}
public func datatoIP(_ data: Data) -> String {
    //93ms 
    if data.count == 4 {
        let length = Int(INET_ADDRSTRLEN)
        var buffer = [CChar](repeating: 0, count: length)
        var p: UnsafePointer<Int8>! = nil
        data.withUnsafeBytes({ (ptr: UnsafePointer<in_addr>)  in
             p = inet_ntop(AF_INET, ptr, &buffer, UInt32(INET_ADDRSTRLEN))
            
        })
        return String(cString:p)
        
    
    }else {
        let length = Int(INET6_ADDRSTRLEN)
        var buffer = [CChar](repeating: 0, count: length)
        var p: UnsafePointer<Int8>! = nil

        
        
        data.withUnsafeBytes({ (ptr: UnsafePointer<in_addr>)  in
            p = inet_ntop(AF_INET, ptr, &buffer, UInt32(INET_ADDRSTRLEN))
            
        })
        return String(cString:p)
        
        
        
    }
    
}
//public func int32toIP(data: NSData) -> String {
//    var ip:String = ""
//    //var p = data.bytes
//    
//    var a:UInt8 = 0
//    data.getBytes(&a, range: NSRange.init(location: 0, length: 1))
//    var  b:UInt8 = 0
//    data.getBytes(&b,range: NSRange.init(location: 1, length: 1))
//    
//    var c:UInt8 = 0
//    data.getBytes(&c, range:NSRange.init(location: 2, length: 1))
//    var  d:UInt8 = 0
//    data.getBytes(&d, range:NSRange.init(location: 3, length: 1))
//    ip = "\(a).\(b).\(c).\(d)"
//    return ip
//}
public func dataToInt(_ data:Data) ->Int32 {
    //var a:Int32 = 0
    let x:Int32  = data.scanValue(start: 0, length: 1)
    //data.getBytes(&a, range: Range(0 ..< 1))
    return x
}
public func data2Int(_ data:Data, len:Int) ->Int32 {
    //var a:Int32 = 0
    var l = 0
    if len > 4 {
        l = 4
    } else {
        l = len
    }
    let x:Int32  = data.scanValue(start: 0, length: l)
    //data.copyBytes(to: &UInt8(a), from: Range( 0 ..< l))
    return x
}
