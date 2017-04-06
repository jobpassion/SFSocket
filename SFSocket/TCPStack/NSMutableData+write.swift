//
//  NSMutableData+write.swift
//  QoodCore
//
//  Created by peng(childhood@me.com) on 15/7/9.
//  Copyright (c) 2015年 xiaop. All rights reserved.
//

import Foundation

extension Data {
    func write<T>(value:T){
        var v = value
        if v is String{
            if let v = v as? String,let data = v.data(using: .utf8, allowLossyConversion: true){
                self.append(data)
            }
        }else if v is Data{
            if let v = v as? Data{
               self.append(v)
            }
        }else if v is UInt8 || v is UInt16 || v is UInt32 || v is UInt64 || v is Int8 || v is Int16 || v is Int32 || v is Int64{
            self.appendBytes(&v, length: sizeof(T))
        }else{
            assertionFailure("write unsupport type")
        }
    }
//    func write(pid:UInt16, block:(Void)->NSData){
//        var data = block()
//        self.write(UInt8(sizeof(UInt16)+data.length+1))
//        self.write(pid)
//        self.appendData(data)
//    }
//    func write<U>(pid:UInt16,value:U){
//        self.write(UInt8(sizeof(UInt16)+sizeof(U)+1))
//        self.write(pid)
//        self.write(value)
//    }
//    func replace(hex:String,with:String) -> NSMutableData{
//        var string = self.toHexString().lowercaseString
//        string = string.stringByReplacingOccurrencesOfString(hex, withString: with, options: NSStringCompareOptions.LiteralSearch, range: nil)
//        return NSData.fromHexString(string).mutableCopy() as! NSMutableData
//    }
}
