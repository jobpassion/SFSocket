//
//  SFRunArgv.swift
//  SFSocket
//
//  Created by 孔祥波 on 06/04/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//
import os.log
import Foundation
import XProxy
import XRuler
import SwiftyJSON
let  fm = FileManager.default
var groupContainerURLVPN:String = ""
func  groupContainerURL() ->URL{
        assert(SKit.groupIdentifier.count != 0)
        return fm.containerURL(forSecurityApplicationGroupIdentifier: SKit.groupIdentifier)!
    
}
enum SFVPNXPSCommand:String{
    case HELLO = "HELLO"
    case RECNETREQ = "RECNETREQ"
    case RULERESULT = "RULERESULT"
    case STATUS = "STATUS"
    case FLOWS = "FLOWS"
    case LOADRULE = "LOADRULE"
    case CHANGEPROXY = "CHANGEPROXY"
    case UPDATERULE = "UPDATERULE"
    var description: String {
        switch self {
        case .LOADRULE: return  "LOADRULE"
        case .HELLO: return "HELLO"
        case .RECNETREQ : return "RECNETREQ"
        case .RULERESULT: return "RULERESULT"
        case .STATUS : return "STATUS"
        case .FLOWS : return "FLOWS"
        case .CHANGEPROXY : return "CHANGEPROXY"
        case .UPDATERULE: return "UPDATERULE"
        }
    }
}
import AxLogger
import NetworkExtension
//let iOSAppIden = "com.yarshure.Surf"
//let iOSTodayIden = "com.yarshure.Surf.SurfToday"
//let MacAppIden = "com.yarshure.Surf.mac"
//let MacTunnelIden = "com.yarshure.Surf.mac.extension"
//let iOSTunnelIden =  "com.yarshure.Surf.PacketTunnel"
//let configMacFn = "abigt.conf"
func ipStringV4(_ ip:UInt32) ->String{
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
            if getnameinfo(value, socklen_t(theAddress.count),
                           &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                let numAddress = String(cString:hostname)
                
                results.append(numAddress)
                
            }
        }
    }
    return results
}


public class SKit {
    static var env = SKit()
    static var app = ""
    static var proxy:XProxy?
    static var sampleConfig = "surf.conf"
    static var DefaultConfig = "Default.conf"

    static let report:SFVPNStatistics = SFVPNStatistics.shared
    
    public static var groupIdentifier = ""
   
    static var alert:Bool = false
    static var configExt = ".conf"
    public static var packetconfig = "group.com.yarshure.config"
    public static var flagconfig = "group.com.yarshure.flag"
    public static var onDemandKey = "com.yarshure.onDemandKey"
    public static var errDomain = "com.abigt.socket"
    

    
    public static var  proxyIpAddr:String = ""
    public static let loopbackAddr:String = "127.0.0.1"
    public static var dnsAddr:String = ""
    public static var proxyHTTPSIpAddr:String = ""
    public static var xxIpAddr:String = ""
    public static var tunIP:String = ""
    
    public static var vpnServer:String = ""
    
    public static var httpProxyPort = 10080
    public static var httpsocketProxyPort = 10081
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
    static var isActive:Bool = false
    public static var lastWakeupTime:Date = Date()
    public static var lastSleepTime:Date = Date()
    static let LimitMemoryUsed:UInt = 13000000//15*1024*1024 //15MB
    static let LimitStartDelay:Int = 10 //10 second
    //let BUF_SIZE:size_t = 2048
    static let LimitSpeedSimgle:UInt = 100*1024 //1KB/ms
    static let LimitLWIPInputSpeedSimgle:UInt = 3*1024 //1KB/ms
    static var memoryLimitUesedSize:UInt = 1*1024*1024
    static let physicalMemorySize = physicalMemory()
    static let LimitSpeedTotal:UInt = 20*1024*1024//LimitSpeedSimgle //1MB/s
    static var packettunnelprovier:NEPacketTunnelProvider?
    static var confirmMessage:Set<String> = []
    public static var debugEnable:Bool = false
    static var packetProcessor:PacketProcessor?
    public static func prepareTunnel(provier:NEPacketTunnelProvider,reset:Bool,pendingStartCompletion: (@escaping (Error?) ->Void)){
        SKit.log("SKit prepareTunnel",level: .Info)
        let setting = NEPacketTunnelNetworkSettings(tunnelRemoteAddress:vpnServer )
        let ipv4 = NEIPv4Settings(addresses: [tunIP], subnetMasks: ["255.255.255.0"])// iPhone @2007 MacWorld
        self.packettunnelprovier = provier
        setting.ipv4Settings = ipv4
        var includedRoutes = [NEIPv4Route]()
        //includedRoutes.append(NEIPv4Route(destinationAddress: "0.0.0.0", subnetMask: "0.0.0.0"))
        if packetProcessor == nil{
            packetProcessor = PacketProcessor.init(p: provier)
        }
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
        
 
        setting.ipv4Settings?.includedRoutes = includedRoutes
        
        
        var excludedRoutes = [NEIPv4Route]()
        
        
        
        
       SKit.log("loading.. proxys", level: .Info)
        
       SKit.log("loading" + ProxyGroupSettings.share.config,level:.Info)
        if !ProxyGroupSettings.share.config.isEmpty {
            SFSettingModule.setting.config(ProxyGroupSettings.share.config)
        }
        for proxy in ProxyGroupSettings.share.proxys {
            let type = proxy.serverAddress.validateIpAddr ()
            if !proxy.serverIP.isEmpty || type == .IPV4 {
                let ip = proxy.serverIP
                
                route = NEIPv4Route(destinationAddress:ip, subnetMask: "255.255.255.255")
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
           
        }
        let ips = query("dns.weixin.qq.com")
        if  !ips.isEmpty {
            let r = DNSCache.init(d: "dns.weixin.qq.com.", i: ips)
            SFSettingModule.setting.addDNSCacheRecord(r)
            SKit.log("DNS \(ips) IN A \(ips)", level: .Trace)
        }else {
            SKit.log("DNS \(ips) IN not found record", level: .Trace)
        }
        
        for v in ips {
            route = NEIPv4Route(destinationAddress: v, subnetMask: "255.255.255.240")
            route.gatewayAddress = NEIPv4Route.default().gatewayAddress
            excludedRoutes.append(route)
        }
        
        setting.ipv4Settings?.excludedRoutes = excludedRoutes
        
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
        if let d = setting.dnsSettings{
            SKit.log("dns setting: \(d)",level: .Info)
        }
        
        
        
        //setting.tunnelOverheadBytes = 150
        setting.mtu = 1500
        setting.proxySettings = NEProxySettings()
        
        
        setting.ipv4Settings?.excludedRoutes = excludedRoutes
        //SKit.log("http \(server) port:\(port)")
        let proxySettings = NEProxySettings()
        
        //SKit.log("http \(server) port:\(port)")
        if SFSettingModule.setting.mode == .socket  {
            proxySettings.httpServer = NEProxyServer(address: loopbackAddr, port: httpsocketProxyPort)
            proxySettings.httpEnabled = true
            
            proxySettings.httpsServer = NEProxyServer(address: loopbackAddr, port: httpsocketProxyPort)
            proxySettings.httpsEnabled = true
            SKit.startGCDProxy(port: Int32(httpsocketProxyPort), dispatchQueue: SFTCPConnectionManager.shared.dispatchQueue, socketQueue: SFTCPConnectionManager.shared.socketQueue)
        }else {
            if SFSettingModule.setting.mode == .tunnel {
                
                proxySettings.httpServer = NEProxyServer(address: proxyIpAddr, port: httpProxyPort)
                proxySettings.httpEnabled = true
                proxySettings.httpsServer = NEProxyServer(address: proxyIpAddr, port: HttpsProxyPort)
                proxySettings.httpsEnabled = true
            }
            
            SFSettingModule.setting.updateProxySetting(setting: proxySettings)
            
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
                self.packettunnelprovier!.displayMessage(message, completionHandler: { (fin) in
                    SKit.log("clicked \(message)",level:.Info)
                    self.confirmMessage.update(with: message)
                })
            } else {
                // Fallback on earlier versions
            }
            
        }
        SKit.log(message,level:.Info)
    }
    public static func wake(){
        SKit.lastWakeupTime = Date()
        isActive = true
        AxLogger.log("Device wake!!!",level: .Notify)
    }
    public static func sleep(completionHandler: @escaping () -> Void){
        SKit.lastSleepTime = Date()
        isActive = false
        AxLogger.log("Device sleep!!!",level: .Notify)
        completionHandler()
    }
 
    static func logX(_ msg:String,level:AxLoggerLevel , category:String="default",file:String=#file,line:Int=#line,ud:[String:String]=[:],tags:[String]=[],time:Date=Date()){
        
        if level != AxLoggerLevel.Debug {
            AxLogger.log(msg,level:level)
        }
        if debugEnable {
            #if os(iOS)
                if #available(iOSApplicationExtension 10.0, *) {
                    os_log("SKit: %@", log: .default, type: .debug, msg)
                } else {
                    print(msg)
                    // Fallback on earlier versions
                }
            #elseif os(OSX)
                if #available(OSXApplicationExtension 10.12, *) {
                    os_log("SKit: %@", log: .default, type: .debug, msg)
                } else {
                    print(msg)
                    // Fallback on earlier versions
                }
                
            #endif
            
            
        }
    }
    static func log(_ msg:String,items: Any...,level:AxLoggerLevel , category:String="default",file:String=#file,line:Int=#line,ud:[String:String]=[:],tags:[String]=[],time:Date=Date()){
       
        if level != AxLoggerLevel.Debug {
            AxLogger.log(msg,level:level)
        }
        if debugEnable {
            #if os(iOS)
                if #available(iOSApplicationExtension 10.0, *) {
                    os_log("SKit: %@", log: .default, type: .debug, msg)
                } else {
                    print(msg)
                    // Fallback on earlier versions
                }
            #elseif os(OSX)
                if #available(OSXApplicationExtension 10.12, *) {
                    os_log("SKit: %@", log: .default, type: .debug, msg)
                } else {
                    print(msg)
                    // Fallback on earlier versions
                }
                
            #endif
            
            
        }
        
       
        
       
    }
    static public  func prepare(_ bundle:String,app:String, config:String) ->Bool{
        SKit.groupIdentifier = bundle
        SKit.app = app
        XRuler.groupIdentifier =  bundle
        
        
        
        ProxyGroupSettings.share.historyEnable = true
        if ProxyGroupSettings.share.historyEnable {
            
            let helper = RequestHelper.shared
            let session = SFEnv.session.idenString()
          
            
            helper.open( session,readonly: false,session: session)
        }
        
        
        if !config.isEmpty {
             ProxyGroupSettings.share.config = config
        }
        SFSettingModule.setting.config(config)
       

        return true

    }
    //为了给VPN提供接口？？
    static public func startGCDProxy(port:Int32,dispatchQueue:DispatchQueue,socketQueue:DispatchQueue){
        if proxy == nil {
            proxy = XProxy()
        }
        proxy?.startGCDProxy(port: port, dispatchQueue: dispatchQueue, socketQueue: socketQueue){ info in
            RequestHelper.shared.saveReqInfo(info);
        }
    }
    static public func stopGCDProxy(){
        
    }
    
    static public func reloadRule(_ path:String){
        SFSettingModule.setting.config(path)
    }
    static public func reloadProxy(){
        do {
            try ProxyGroupSettings.share.loadProxyFromFile()
        } catch let e {
            SKit.logX("\(e.localizedDescription)", level: .Error)
        }
        
    }
    public static  func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let messageString = String.init(data: messageData, encoding: .utf8) else {
            completionHandler?("no data from app".data(using: .utf8))
            return
        }
        
        //NSLog("handleAppMessage " + (messageString as String))
        if SFTCPConnectionManager.shared.lwip_init_finished == false {
            NSLog("Warning lwip not ready")
        }
        //NSLog("#####Got a message from the app \(reportMemory())")
        let packet = messageString.components(separatedBy: "|")
        guard  let command = packet.first else {return }
        
        if let x = SFVPNXPSCommand(rawValue:command) {
            switch x {
            case .LOADRULE:
                
                if  packet.count >= 2 {
                    let rule = packet[1]
                    //SKit.reloadRule(rule)
                    let responseData = (rule + "Loaded") .data(using: String.Encoding.utf8)
                    completionHandler?(responseData)
                }
            case .HELLO:
                let mem = String(reportMemoryUsed())
                let x = "hello app memory:" + mem  + " session:" + SFEnv.session.idenString()
                
                let responseData = x.data(using: String.Encoding.utf8)
                completionHandler?(responseData)
                
            case .RECNETREQ:
                //AxLogger.log("RECNETREQ RPC Request",level: .Debug)
                let responseData = SFTCPConnectionManager.shared.recentRequestData()
                
                completionHandler?(responseData)
            case .RULERESULT:
                let responseData = SFTCPConnectionManager.shared.ruleResultData()
                completionHandler?(responseData)
            case .STATUS:
                let responseData = report.report(memory: reportMemoryUsed(), count: SFTCPConnectionManager.shared.connections.count)
                completionHandler?(responseData)
            case .CHANGEPROXY:
                guard  let selectIndex = packet.last else {return }
                var message = ""
                if let i = Int(selectIndex){
                    ProxyGroupSettings.share.selectIndex = i
                    ProxyGroupSettings.share.dynamicSelected = true
                    message = "select proxy changed"
                }else {
                    message = "select proxy error"
                }
                
                //AxLogger.log(message,level: .Info)
                SFTCPConnectionManager.shared.clearRule()
                //AxLogger.log("Rule Test Results clean",level: .Info)
                completionHandler?(message.data(using: .utf8, allowLossyConversion: false))
            case .FLOWS:
                let data = report.flowData(memory:reportMemoryUsed())
                completionHandler?(data)
            case .UPDATERULE:
                //fixme
                //                guard  let message = packet.last else {return}
                //                if let data = message.data(using: String.Encoding.utf8, allowLossyConversion: false){
                //                    let json = JSON.init(data: data)
                //                    let request = json["request"].stringValue
                //                    let rulerj = json["ruler"]
                //                    let r = SFRuler()
                //                    r.mapObject(rulerj)
                //                    if !request.isEmpty{
                //                        let result = SFRuleResult.init(request: request, r: r)
                //                        SFTCPConnectionManager.shared().updateRuleResult(result)
                //                        let m = "UPDATERULE \(request) OK"
                //                        completionHandler?(m.data(using: .utf8, allowLossyConversion: false))
                //                        return
                //                    }
                
                //}
                completionHandler?("UPDATERULE failure".data(using: .utf8))
                break
            }
        }
    }
    func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {

        //        DispatchQueue.main.async {
        //
        //
        //
        //        }
//        Answers.logCustomEvent(withName: "VPN",
//                               customAttributes: [
//                                "Stop": "OK",
//
//                                ])
//        self.pendingStopCompletion = completionHandler
//        //        setTunnelNetworkSettings(nil) { [unowned self ] error in
//        //
//        //        }
//        AxLogger.log("stoping",level: .Info)
//
//        //let manager = SFTCPConnectionManager.manager
//        //manager.stop()
//
//        self.logStopReason(reason: reason)
//
//        self.udpStack.stop()
//
//        self.pendingStopCompletion!()
//        self.pendingStopCompletion = nil
//        self.stopABigT()
//        //        let end = NSDate().timeIntervalSince(SFVPNStatistics.shared.sessionStartTime)
//        //
//        //        let sec = String(format: "%.0f",end)
//        AxLogger.log("A.BIG.T running \(sec) second", level: .Info)
//        AxLogger.log("A.BIG.T Stopped", level: .Info)
//
//        _exit(0)


    }
    
}


