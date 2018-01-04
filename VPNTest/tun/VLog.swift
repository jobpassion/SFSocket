//
//  VLog.swift
//  VPNTest
//
//  Created by yarshure on 2018/1/3.
//  Copyright © 2018年 Kong XiangBo. All rights reserved.
//

import Foundation
import os.log
import AxLogger
//bug app->kernle->tun--|
//-----------|--socket<--|
class VLog {
    static func log(_ msg:String,level:AxLoggerLevel , category:String="default",file:String=#file,line:Int=#line,ud:[String:String]=[:],tags:[String]=[],time:Date=Date()){
        
        os_log("VPN: %@", log: .default, type: .debug, msg)
        
        // print(msg)
        
        
    }
}
//public func simpleTunnelLog(_ message: String) {
//    
//    os_log("XProxy: %@", log: .default, type: .debug, message)
//}

