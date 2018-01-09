//
//  SFTunUtility.swift
//  Surf
//
//  Created by 孔祥波 on 7/5/16.
//  Copyright © 2016 yarshure. All rights reserved.
//

import Foundation
import AxLogger
public func memoryUsed() -> String {
    let mem:UInt64 =  reportMemoryUsed()
    return memoryString(mem)
}
func memoryString(_ memoryUsed:UInt64) ->String {
    let f = Float(memoryUsed)
    if memoryUsed < 1024 {
        return "\(memoryUsed) Bytes"
    }else if memoryUsed >=  1024 &&  memoryUsed <  1024*1024 {
        
        return  String(format: "%.2f KB", f/1024.0)
    }
    return String(format: "%.2f MB", f/1024.0/1024.0)
    
}
