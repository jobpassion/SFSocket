//
//  SFDNSManager.swift
//  Surf
//
//  Created by 孔祥波 on 8/3/16.
//  Copyright © 2016 yarshure. All rights reserved.
//

import Foundation
import AxLogger
import DarwinCore
class SFDNSManager {
    static let manager = SFDNSManager()
    var settings:[DNSServer] = []
    var index:Int = 0
    var userSetDNS = false
    var dnsServers:[String] = []
    func setUpConfig(_ opt:[String]?) ->[DNSServer]{
        
        var result:[DNSServer] = []
        if let opt = opt, !opt.isEmpty {
            userSetDNS = true
            for o in opt{
                let uper = o.uppercased()
                if uper == "SYSTEM"{
                    addSystemDNS(&result)
                }else {
                    let d = DNSServer.init(ip: o,sys:false)
                    //settings.append(d)
                    result.append(d)
                }
            }
        }else {
            addSystemDNS(&result)
        }
        return result
        //maybe add default
    }
    func addSystemDNS( _ result:inout [DNSServer]) {
        let system = DNSServer.currentSystemDns()
        for s in system {
            if  s == SKit.env.proxyIpAddr {
                AxLogger.log("DNS invalid \(s) ",level: .Error)
            }else {
                
                if !s.isEmpty{
                    let d = DNSServer.init(ip: s,sys:true)
                    //settings.append(d)
                    result.append(d)
                    
                    SFEnv.env.updateEnvIP(s)
                    AxLogger.log("system dns \(s) type:\( SFEnv.env.ipType)",level: .Info)
                }
                
            }
            
        }
    }
    func currentDNSServer() -> [String] {
        
        
        let dnss = DNS.loadSystemDNSServer()
        if let f = dnss?.first, f == SKit.env.proxyIpAddr {
            AxLogger.log("DNS don't need  update",level: .Info)
        }else {
            dnsServers.removeAll()
            for item in dnss!{
                dnsServers.append(item)
            }
            AxLogger.log("System DNS \(dnsServers)",level: .Info)
        }
        
        
        
        return dnsServers
        
    }
    func giveMeAserver() ->DNSServer{
        
        
        if index == settings.count  {
            index = 0
        }
        
        if index < settings.count{
            let s = settings[index]
            index += 1
            return s

        }else {
            return DNSServer.createSetting()
        }
        
        
        
    }
    func tunDNSSetting() ->[String]{
        if SFEnv.env.ipType == .ipv6 {
            return DNSServer.currentSystemDns()
        }else {
            return  DNSServer.tunIPV4DNS
        }
    }
    func updateSetting() ->[DNSServer]{
        
        var result:[DNSServer]
        if let r = SFSettingModule.setting.rule, let g = r.general{
             result  = setUpConfig(g.dnsserver)
        }else {
            result = setUpConfig(nil)
        }
        settings = result
        
        //SFNetworkInterfaceManager.instances.updateIPAddress()
        //settings.removeAll()
        //settings.appendContentsOf(result)
       
        return result
    }
}
