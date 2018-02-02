//
//  DNSServer.swift
//  Surf
//
//  Created by 孔祥波 on 8/3/16.
//  Copyright © 2016 yarshure. All rights reserved.
//

import Foundation
import Darwin
import DarwinCore
import XRuler
public class DNSServer :CustomStringConvertible {
    public var ipaddr:String
    public var system:Bool = false
    public var type:SFNetWorkIPType
    public var successCount:Int = 0
    public var failureCount:Int = 0
    public var totalTime:Double = 0.0
    public init(ip:String,sys:Bool){
        ipaddr = ip
        system = sys
        type = SFNetWorkIPType.init(ip: ip)
    }
    public static func currentSystemDns() ->[String] {
        let dnss = DNS.loadSystemDNSServer()
        return dnss!
    }
    public static func createSetting() ->DNSServer {
        let count = DNSServer.default_servers.count
        let value = Int(arc4random()) % count;
        let x = DNSServer.default_servers[value]
        let r = DNSServer.init(ip: x, sys: false)
        return r
    }
    static let tunIPV4DNS = ["240.7.1.10"]
    static let  default_servers = ["119.29.29.29","223.6.6.6", "223.5.5.5"]
    public var description: String {
        return "\(ipaddr)"
    }
}
