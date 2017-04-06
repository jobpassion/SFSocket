//
//  SFVPNSession.swift
//  Surf
//
//  Created by yarshure on 2016/8/5.
//  Copyright © 2016年 yarshure. All rights reserved.
//

import Foundation

//历史统计功能
class SFVPNSession:NSObject {
    static  let session = SFVPNSession()
    var startTime:Date = Date()
    var endTime : Date = Date(timeIntervalSince1970:0)
    
    
    
    
    init(path:String) {
        
    }
    override init(){
        
    }
    func idenString() ->String {
        let f = DateFormatter();
        f.dateFormat = "yyyy_MM_dd_HH_mm_ss";
        return f.string(from: startTime)
    }
    func shortIdenString() ->String {
        let f = DateFormatter();
        f.dateFormat = "yyyy_MM_dd_HH_mm_ss";
        return f.string(from: startTime)
    }
}
