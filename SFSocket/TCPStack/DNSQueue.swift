//
//  DNSQueue.swift
//  Surf
//
//  Created by 孔祥波 on 7/27/16.
//  Copyright © 2016 yarshure. All rights reserved.
//

import Foundation

struct  DNSQueue {
    var connection:SFConnection
    var hostname:String
    init(c:SFConnection, h:String){
        connection = c
        hostname = h
    }
    
}