//
//  File.swift
//  SFSocket
//
//  Created by yarshure on 2017/6/5.
//  Copyright © 2017年 Kong XiangBo. All rights reserved.
//

import Foundation
import snappy
class SnappyHelper {
    static func compress(_ data:Data) ->Data{
        
        let count:UnsafeMutablePointer<Int> = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        count.pointee =  snappy_max_compressed_length(data.count)
        let out:UnsafeMutablePointer<Int8> = UnsafeMutablePointer<Int8>.allocate(capacity: count.pointee)
        defer {
            out.deallocate(capacity: count.pointee)
            count.deallocate(capacity: 1)
            
        }
        data.withUnsafeBytes { (input: UnsafePointer<Int8>) -> Void in
            if snappy_compress(input, data.count, out, count) == SNAPPY_OK {
                SKit.log("ok \(count.pointee)",level:.Info)
                
            }
        }
        
        
        //let raw = UnsafeRawPointer.init(out)
        let result = Data(buffer: UnsafeBufferPointer(start:out,count:count.pointee))
        //print("out \(count.pointee) \(result as NSData)")
        return result
        //testDecomp(st, mid: result)
    }
    static func decompress(_ data:Data) ->Data{
        let count:UnsafeMutablePointer<Int> = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        count.pointee =  snappy_max_compressed_length(data.count)
        let out:UnsafeMutablePointer<Int8> = UnsafeMutablePointer<Int8>.allocate(capacity: count.pointee)
        defer {
            out.deallocate(capacity: count.pointee)
            count.deallocate(capacity: 1)
            
        }
        
        data.withUnsafeBytes { (input: UnsafePointer<Int8>) -> Void in
            if snappy_uncompress(input, data.count, out, count) == SNAPPY_OK {
                print("ok \(count.pointee)")
            }
        }
        let result = Data(buffer: UnsafeBufferPointer(start:out,count:count.pointee))
        //print("out \(count.pointee) \(result as NSData)")
        return result
    }
}
