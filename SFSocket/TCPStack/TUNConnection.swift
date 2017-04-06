//
//  TUNConnection.swift
//  Surf
//
//  Created by 孔祥波 on 16/2/6.
//  Copyright © 2016年 yarshure. All rights reserved.
//

import Foundation

class TUNConnection: NSObject {
    let info:SFIPConnectionInfo
    var forceSend:Bool = false // client maybe close after send, proxy should sending the buffer
    var closeSocketAfterRead:Bool = false // HTTP 
    init(i:SFIPConnectionInfo) {
        info = i
        super.init()
    }
    
}
