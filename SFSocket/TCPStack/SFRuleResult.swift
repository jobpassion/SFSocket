//
//  SFRuleResult.swift
//  Surf
//
//  Created by yarshure on 16/2/5.
//  Copyright © 2016年 yarshure. All rights reserved.
//

import Foundation
import AxLogger
public enum SFRuleResultMethod :Int, CustomStringConvertible{
    case cache = 0
    case sync = 1
    case async = 2
    public var description: String {
        switch self {
        case .cache: return "Cache"
        case .sync: return "Sync"
        case .async: return "Async"
        
        }
    }
}
class SFRuleResult {
    var req:String = ""
    var result:SFRuler
    var ipAddr:String = ""
    var method:SFRuleResultMethod = SFRuleResultMethod.init(rawValue: 0)!
    init(request:String, r:SFRuler) {
        req = request
        result = r
    }
    func resp() -> [String:AnyObject] {
        var r:[String:AnyObject] = [:]
        r[req] = result.resp() as AnyObject?
        return r
    }
    deinit {
        AxLogger.log("[SFSettingModule] RuleResult deinit ",level: .Debug)
    }
}
