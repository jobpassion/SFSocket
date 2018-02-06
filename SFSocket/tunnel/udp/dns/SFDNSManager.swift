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
import XRuler
open class SFDNSManager {
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
            if  s == SKit.proxyIpAddr {
                SKit.log("DNS invalid \(s) ",level: .Error)
            }else {
                
                if !s.isEmpty{
                    let d = DNSServer.init(ip: s,sys:true)
                    //settings.append(d)
                    result.append(d)
                    
                    SFEnv.updateEnvIP(s)
                    SKit.log("system dns \(s) type:\( SFEnv.ipType)",level: .Info)
                }
                
            }
            
        }
    }
    func currentDNSServer() -> [String] {
        
        
        let dnss = DNS.loadSystemDNSServer()
        if let f = dnss?.first, f == SKit.proxyIpAddr {
            SKit.log("DNS don't need  update",level: .Info)
        }else {
            dnsServers.removeAll()
            for item in dnss!{
                dnsServers.append(item)
            }
            SKit.log("System DNS \(dnsServers)",level: .Info)
        }
        
        
        
        return dnsServers
        
    }
    func giveMeAserver(system:Bool) ->DNSServer{
        
        if system {
            let ls = settings.filter{$0.system}
            if !ls.isEmpty {
                return ls.first!
            }
        }
        
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
        if SFEnv.ipType == .ipv6 {
            return DNSServer.currentSystemDns()
        }else {
            return  DNSServer.tunIPV4DNS
        }
    }
    func updateSetting() ->[DNSServer]{
        
        var result:[DNSServer] 
        //MARK --fixme
        let custom = SFSettingModule.setting.custormDNS()
        if  !custom.isEmpty{
             result  = setUpConfig(custom)
        }else {
             result =  setUpConfig(nil)
        }
        settings = result
        
        //SFNetworkInterfaceManager.instances.updateIPAddress()
        //settings.removeAll()
        //settings.appendContentsOf(result)
       
        return result
    }
}
