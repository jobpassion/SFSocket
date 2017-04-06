//
//  SFIPInfo.swift
//  Surf
//
//  Created by 孔祥波 on 16/2/6.
//  Copyright © 2016年 yarshure. All rights reserved.
//

import Foundation

struct  SFIPConnectionInfo{
    var tun:IPAddr
    var remote:IPAddr
    init(si:UInt32,sp:UInt16,ri:UInt32,rp:UInt16) {
        tun = IPAddr.init(i:si, p:sp)
        remote = IPAddr.init(i:ri, p:rp)
    }
    init(t:IPAddr, r:IPAddr){
        tun = t
        remote = r
    }
    func equalInfo(_ info:SFIPConnectionInfo) -> Bool {
        if self.tun.equal(info.tun) && self.remote.equal(info.remote) {
            return true
        }
        return false
    }
}
