//
//  SFRunArgv.swift
//  SFSocket
//
//  Created by 孔祥波 on 06/04/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//

import Foundation
let  fm = FileManager.default
var groupContainerURLVPN:String = ""
func  groupContainerURL() ->URL{
   
        return fm.containerURL(forSecurityApplicationGroupIdentifier: SKit.groupIdentifier)!
  
        
    //#endif
    //return URL.init(fileURLWithPath: "")
    
}
import AxLogger
import NetworkExtension
//let iOSAppIden = "com.yarshure.Surf"
//let iOSTodayIden = "com.yarshure.Surf.SurfToday"
//let MacAppIden = "com.yarshure.Surf.mac"
//let MacTunnelIden = "com.yarshure.Surf.mac.extension"
//let iOSTunnelIden =  "com.yarshure.Surf.PacketTunnel"
//let configMacFn = "abigt.conf"
func ipString(_ ip:UInt32) ->String{
    let a = (ip & 0xFF)
    let b = (ip >> 8 & 0xFF)
    let c = (ip >> 16 & 0xFF)
    let d = (ip >> 24 & 0xFF)
    return "\(a)." + "\(b)." + "\(c)." + "\(d)"
}
func queryDNS(_ domains:[String]) ->[String]{
    var records:[String] = []
    for domain in domains {
        let list = query(domain)
        if list.count > 0 {
            records.append(contentsOf: list)
        }
        
        
    }
    return records
}
func query(_ domain:String) ->[String] {
    var results:[String] = []
    
    let host = CFHostCreateWithName(nil,domain as CFString).takeRetainedValue()
    
    
    CFHostStartInfoResolution(host, .addresses, nil)
    var success: DarwinBoolean = false
    if let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as NSArray? {
        
        for s in  addresses{
            let theAddress =  s as! Data
            var hostname = [CChar](repeating: 0, count: Int(256))
            
            let p = theAddress as Data
            let value = p.withUnsafeBytes { (ptr: UnsafePointer<sockaddr>)  in
                return ptr
            }
            if getnameinfo(value, socklen_t(theAddress.length),
                           &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                let numAddress = String(cString:hostname)
                
                results.append(numAddress)
                
            }
            
            
        }
        
        
    }
    return results
}
//var kProxyGroupFile = ".ProxyGroup"

public class SKit {
    static var env = SKit()
    static var sampleConfig = "surf.conf"
    static var DefaultConfig = "Default.conf"
    //let kSelect = "kSelectConf"
    
    //var groupIdentifier = ""
    
    
    #if os(iOS)
    public static var groupIdentifier = "group.com.yarshure.Surf"
    #else
    public static var groupIdentifier = "745WQDK4L7.com.yarshure.Surf"
    #endif
    static var alert:Bool = false
    static var configExt = ".conf"
    public static var packetconfig = "group.com.yarshure.config"
    public static var flagconfig = "group.com.yarshure.flag"
    public static var onDemandKey = "com.yarshure.onDemandKey"
    public static var errDomain = "com.abigt.socket"
    
    
    //#if os(iOS)
    public static var  proxyIpAddr:String = "240.7.1.10"
    public static let loopbackAddr:String = "127.0.0.1"
    public static var dnsAddr:String = "218.75.4.130"
    public static var proxyHTTPSIpAddr:String = "240.7.1.11"
    public static var xxIpAddr:String = "240.7.1.12"
    public static var tunIP:String = "240.7.1.9"
    //    #else
    //let proxyIpAddr:String = "240.0.0.3"
    //let dnsAddr:String = "218.75.4.130"
    //let proxyHTTPSIpAddr:String = "240.7.1.11"
    //let tunIP:String = "240.200.200.200"
    //    #endif
    public static var vpnServer:String = "240.89.6.4"
    
    public static var httpProxyPort = 10080
    public static var httpsocketProxyPort = 10080
    public static var HttpsProxyPort = 10081
    
    static var agentsFile = "useragents.plist"
    static var kProxyGroup = "ProxyGroup"
    public static var kProxyGroupFile = ".ProxyGroup"
    static var groupContainerURLVPN:String = ""
    
    public static var iOSAppIden = "com.yarshure.Surf"
    public static var iOSTodayIden = "com.yarshure.Surf.SurfToday"
    public static var MacAppIden = "com.yarshure.Surf.mac"
    public static var MacTunnelIden = "com.yarshure.Surf.mac.extension"
    public static var iOSTunnelIden =  "com.yarshure.Surf.PacketTunnel"
    public static var configMacFn = "abigt.conf"
    
    
    static let socketReadTimeout = 15.0
    static let AsyncSocketReadTimeOut = 3.0*200// 3.0*200
    static let AsyncSocketWriteTimeOut = 15.0
    static let  READ_TIMEOUT = 15.0
    static let  READ_TIMEOUT_EXTENSION = 10.0
    static let lwip_timer_second = 0.250
    
    
    static let TCP_MEMORYWARNING_TIMEOUT:TimeInterval = 2
    
    
    static let HTTP_CONNECTION_TIMEOUT:TimeInterval = 5
    static let TCP_CONNECTION_TIMEOUT:TimeInterval = 600 //HTTP_CONNECTIPN_TIMEPUT*6
    static let HTTPS_CONNECTION_TIMEOUT:TimeInterval = 60//HTTP_CONNECTIPN_TIMEPUT*3
    static let vpn_status_timer_second = 1.0
    
    static let RECENT_REQUEST_LENGTH:Int = 20
    static let SOCKET_DELAY_READ: TimeInterval = 0.050
    static let SFTCPManagerEnableDropTCP = false
    static let LimitTCPConnectionCount_DELAY:Int = 0
    static let LimitTCPConnectionCount:Int = 10
    static let LimitTCPConnectionCount_DROP:Int = 15
    static let TCP_DELAY_START = 0.5
    static let LimitMemoryUsed:UInt = 13000000//15*1024*1024 //15MB
    static let LimitStartDelay:Int = 10 //10 second
    //let BUF_SIZE:size_t = 2048
    static let LimitSpeedSimgle:UInt = 100*1024 //1KB/ms
    static let LimitLWIPInputSpeedSimgle:UInt = 3*1024 //1KB/ms
    static var memoryLimitUesedSize:UInt = 1*1024*1024
    static let physicalMemorySize = physicalMemory()
    static let LimitSpeedTotal:UInt = 20*1024*1024//LimitSpeedSimgle //1MB/s
    static var provier:NEPacketTunnelProvider?
    static var confirmMessage:Set<String> = []
    public static func prepareTunnel(provier:NEPacketTunnelProvider,reset:Bool,pendingStartCompletion: (@escaping (Error?) ->Void)){
        SKit.log("SKit prepareTunnel",level: .Info)
        let setting = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "240.89.6.4")
        let ipv4 = NEIPv4Settings(addresses: [tunIP], subnetMasks: ["255.255.255.0"])// iPhone @2007 MacWorld
        self.provier = provier
        setting.iPv4Settings = ipv4
        var includedRoutes = [NEIPv4Route]()
        //includedRoutes.append(NEIPv4Route(destinationAddress: "0.0.0.0", subnetMask: "0.0.0.0"))
        
        let defaultRoute = NEIPv4Route.default()
        let dest = defaultRoute.destinationAddress as String
        if reset {
            if dest == "0.0.0.0" && defaultRoute.gatewayAddress == nil{
                includedRoutes.append(defaultRoute)
                //SKit.log("default router: \(defaultRoute.destinationAddress) \(defaultRoute.gatewayAddress)",level:.Debug)
            }else {
                //SKit.log("default router####: \(defaultRoute.destinationAddress) \(defaultRoute.gatewayAddress)",level:.Debug)
            }
        }else {
            includedRoutes.append(defaultRoute)
        }
        
        
        //if defaultRoute.gatewayAddress =
        
        
        var route = NEIPv4Route(destinationAddress: proxyIpAddr, subnetMask: "255.255.255.0")
        route.gatewayAddress = tunIP
        includedRoutes.append(route)
        
        //        route = NEIPv4Route(destinationAddress: "0.0.0.0", subnetMask: "0.0.0.0")
        //        route.gatewayAddress = tunIP
        //        includedRoutes.append(route)
        setting.iPv4Settings?.includedRoutes = includedRoutes
        
        
        var excludedRoutes = [NEIPv4Route]()
        
        guard let rule = SFSettingModule.setting.rule else  {
            let reason = NEProviderStopReason.providerFailed
            #if os(iOS)
            provier.alert(message: "Don't Find Conf File,Please Use Main Application Dial VPN",reason:reason)
                #endif
            SKit.log("Don't find conf file",level: .Error)
            return
        }
        if let general =  rule.general  {
            SKit.log("Bypass-tun count \(general.bypasstun.count) ",level: .Info)
            for item in general.bypasstun {
                let x = item.components(separatedBy: "/")
                if x.count == 2{
                    if let net = x.first, let mask = x.last {
                        //2,3,4
                        let netmask :UInt32 = 0xffffffff << (32 - UInt32( mask)!)
                        
                        route = NEIPv4Route(destinationAddress: net, subnetMask: ipString(netmask.byteSwapped))
                        route.gatewayAddress = NEIPv4Route.default().gatewayAddress
                        excludedRoutes.append(route)
                    }
                }
            }
        }
        
        
        
        
        
        
        
        for proxy in ProxyGroupSettings.share.proxys {
            let type = proxy.serverAddress.validateIpAddr ()
            if !proxy.serverIP.isEmpty || type == .IPV4 {
                let ip = proxy.serverIP
                
                route = NEIPv4Route(destinationAddress:ip, subnetMask: "255.255.255.255")
                //NSLog("%@ %@ %@",proxy.proxyName,proxy.serverAddress, proxy.serverIP)
                route.gatewayAddress = NEIPv4Route.default().gatewayAddress
                excludedRoutes.append(route)
            }else {
                let wxRecords = query(proxy.serverAddress)
                SKit.log(" pass tun proxy.serverAddress:\(wxRecords)",level: .Info)
                for v in wxRecords {
                    route = NEIPv4Route(destinationAddress: v, subnetMask: "255.255.255.240")
                    route.gatewayAddress = NEIPv4Route.default().gatewayAddress
                    excludedRoutes.append(route)
                }
                
            }
        }
        if  ProxyGroupSettings.share.proxyChain {
            SKit.log("Proxy Chain Enable",level:.Info)
            ProxyChain.shared.proxy = ProxyGroupSettings.share.chainProxy
        }
        let ips = query("dns.weixin.qq.com")
        if  !ips.isEmpty {
            let r = DNSCache.init(d: "dns.weixin.qq.com.", i: ips)
            SFSettingModule.setting.addDNSCacheRecord(r)
            SKit.log("DNS \(ips) IN A \(ipString)", level: .Trace)
        }else {
            SKit.log("DNS \(ips) IN not found record", level: .Trace)
        }
        
        for v in ips {
            route = NEIPv4Route(destinationAddress: v, subnetMask: "255.255.255.240")
            route.gatewayAddress = NEIPv4Route.default().gatewayAddress
            excludedRoutes.append(route)
        }
        
        setting.iPv4Settings?.excludedRoutes = excludedRoutes
        
        let dnsservers =  SFDNSManager.manager.updateSetting()
        if let path = provier.defaultPath {
            if path.isExpensive {
                SKit.log("Cell DNS \(dnsservers)",level: .Info)
            }else {
                SKit.log("WI-FI DNS \(dnsservers)",level: .Info)
            }
            
        }
        let dnsSetting =  SFDNSManager.manager.tunDNSSetting()
        setting.dnsSettings = NEDNSSettings(servers: dnsSetting)
        if let _ = setting.dnsSettings{
            //SKit.log("dns setting: \(d)",level: .Info)
            
            
        }
        
        //mylog("dns " + dns)
        
        //setting.tunnelOverheadBytes = 150
        setting.mtu = 1500
        setting.proxySettings = NEProxySettings()
        
        
        setting.iPv4Settings?.excludedRoutes = excludedRoutes
        //SKit.log("http \(server) port:\(port)")
        let proxySettings = NEProxySettings()
        
        //SKit.log("http \(server) port:\(port)")
        if SFSettingModule.setting.httpProxyModeSocket  {
            proxySettings.httpServer = NEProxyServer(address: loopbackAddr, port: httpsocketProxyPort)
            proxySettings.httpEnabled = true
            
            proxySettings.httpsServer = NEProxyServer(address: loopbackAddr, port: httpsocketProxyPort)
            proxySettings.httpsEnabled = true
        }else {
            if SFSettingModule.setting.httpProxyEnable {
                
                proxySettings.httpServer = NEProxyServer(address: proxyIpAddr, port: httpProxyPort)
                proxySettings.httpEnabled = true
            }
            if SFSettingModule.setting.httpsProxyEnable {
                proxySettings.httpsServer = NEProxyServer(address: proxyIpAddr, port: HttpsProxyPort)
                proxySettings.httpsEnabled = true
            }
            if let g =  SFSettingModule.setting.rule!.general{
                if !g.skipproxy.isEmpty {
                    proxySettings.exceptionList  = g.skipproxy
                }
                
                proxySettings.excludeSimpleHostnames = true
                
            }
            
        }
        
        
        if SFSettingModule.setting.socksProxyEnable  {
            proxySettings.autoProxyConfigurationEnabled = true
            if let path = Bundle.main.path(forResource:"socks5.js", ofType: "") {
                do {
                    let js = try  String.init(contentsOfFile: path)
                    proxySettings.proxyAutoConfigurationJavaScript = js
                }catch let e as NSError {
                    SKit.log("Now use autoproxy!!!!! \(e)",level:.Info)
                }
                
                
            }
            
        }
        
        proxySettings.excludeSimpleHostnames = true
        setting.proxySettings  = proxySettings
        
        provier.setTunnelNetworkSettings(setting) {  error in
            pendingStartCompletion(error)
            
           
            
        }
    }
    static public func writestart() {
        //SKit.log("mem:\(memoryUsed()) VPN:starting ",level: .Info)
        
        //SKit.log("App Info:\(appInfo())",level:.Info)
        SKit.log("App Info:\(appInfo())",level: .Info)
        if SFSettingModule.setting.udprelayer {
            SKit.log("UDP forward enabled",level: .Info)
        }
        
    }
    static func alertMessage(_ message:String){
        if !alert {
            return
        }
        if self.confirmMessage.contains(message){
            return
        }
        SKit.log("will alert \(message)",level:.Info)
        if #available(iOSApplicationExtension 10.0, *) {
            //VPN can alert
            if #available(OSXApplicationExtension 10.12, *) {
                self.provier!.displayMessage(message, completionHandler: { (fin) in
                    SKit.log("clicked \(message)",level:.Info)
                    self.confirmMessage.update(with: message)
                })
            } else {
                // Fallback on earlier versions
            }
            
        }
        SKit.log(message,level:.Info)
    }
    static public func loadConfig(){
        
        
        
        var   fn = ProxyGroupSettings.share.config
        //Mac 用单一文件
        if fn.isEmpty {
            fn  = "abigt.conf"
        }else {
            #if os(macOS)
                fn = "abigt.conf"
            #endif
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        formatter.timeZone = NSTimeZone.system
        SKit.log("Config FileModificationDate \(formatter.string(from: SFSettingModule.setting.configFileData as Date))",level:.Info)
        let  path = groupContainerURL().appendingPathComponent(fn).path
        SFSettingModule.setting.config(path)
        
        
        
        
        
        
        //SKit.log("",level: .Debug)
        
    }
    static func logX(_ msg:String,level:AxLoggerLevel , category:String="default",file:String=#file,line:Int=#line,ud:[String:String]=[:],tags:[String]=[],time:Date=Date()){
        #if Debug
            AxLogger.log(msg,level:level)
        #else
            if level != AxLoggerLevel.Debug {
                AxLogger.log(msg,level:level)
            }
        #endif
    }
    static func log(_ msg:String,items: Any...,level:AxLoggerLevel , category:String="default",file:String=#file,line:Int=#line,ud:[String:String]=[:],tags:[String]=[],time:Date=Date()){
       
        #if Debug
            
            //AxLogger.log(msg,level:level)
            print(msg)
        #else
            //if level != AxLoggerLevel.Debug {
            //    AxLogger.log(msg,level:level)
            //}
        #endif
    }
    static public  func prepare() ->Bool{
        SKit.loadConfig()
        let  pp = ProxyGroupSettings.share
        print(pp.proxys.count)
        
        if let  rule = SFSettingModule.setting.rule {
            print("rule inited \(rule.cnIPCount)")
            return true
        }else {
            print("rule not init")
            return false
        }
        

    }
    static public func startGCDProxy(){
        SFTCPConnectionManager.manager.startGCDServer()
    }
    
   
}
