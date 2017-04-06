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
   
        return fm.containerURL(forSecurityApplicationGroupIdentifier: SKit.env.groupIdentifier)!
  
        
    //#endif
    //return URL.init(fileURLWithPath: "")
    
}
let iOSAppIden = "com.yarshure.Surf"
let iOSTodayIden = "com.yarshure.Surf.SurfToday"
let MacAppIden = "com.yarshure.Surf.mac"
let MacTunnelIden = "com.yarshure.Surf.mac.extension"
let iOSTunnelIden =  "com.yarshure.Surf.PacketTunnel"
let configMacFn = "abigt.conf"

var kProxyGroupFile = ".ProxyGroup"
public class SKit {
    static var env = SKit()
    var sampleConfig = "surf.conf"
    var DefaultConfig = "Default.conf"
    //let kSelect = "kSelectConf"
    
    //var groupIdentifier = ""
    
    
    #if os(iOS)
    var groupIdentifier = "group.com.yarshure.Surf"
    #else
    var groupIdentifier = "745WQDK4L7.com.yarshure.Surf"
    #endif
    var configExt = ".conf"
    var packetconfig = "group.com.yarshure.config"
    var flagconfig = "group.com.yarshure.flag"
    var onDemandKey = "com.yarshure.onDemandKey"
    var errDomain = "com.abigt.socket"
    
    
    //#if os(iOS)
    var  proxyIpAddr:String = "240.7.1.10"
    let loopbackAddr:String = "127.0.0.1"
    var dnsAddr:String = "218.75.4.130"
    var proxyHTTPSIpAddr:String = "240.7.1.11"
    var xxIpAddr:String = "240.7.1.12"
    var tunIP:String = "240.7.1.9"
    //    #else
    //let proxyIpAddr:String = "240.0.0.3"
    //let dnsAddr:String = "218.75.4.130"
    //let proxyHTTPSIpAddr:String = "240.7.1.11"
    //let tunIP:String = "240.200.200.200"
    //    #endif
    var vpnServer:String = "240.89.6.4"
    
    var httpProxyPort = 10080
    var httpsocketProxyPort = 10080
    var HttpsProxyPort = 10081
    
    var agentsFile = "useragents.plist"
    var kProxyGroup = "ProxyGroup"
    var kProxyGroupFile = ".ProxyGroup"
    var groupContainerURLVPN:String = ""
    
    var iOSAppIden = "com.yarshure.Surf"
    var iOSTodayIden = "com.yarshure.Surf.SurfToday"
    var MacAppIden = "com.yarshure.Surf.mac"
    var MacTunnelIden = "com.yarshure.Surf.mac.extension"
    var iOSTunnelIden =  "com.yarshure.Surf.PacketTunnel"
    var configMacFn = "abigt.conf"
    
    
    let socketReadTimeout = 15.0
    let AsyncSocketReadTimeOut = 3.0*200// 3.0*200
    let AsyncSocketWriteTimeOut = 15.0
    let  READ_TIMEOUT = 15.0
    let  READ_TIMEOUT_EXTENSION = 10.0
    let lwip_timer_second = 0.250
    
    
    let TCP_MEMORYWARNING_TIMEOUT:TimeInterval = 2
    
    
    let HTTP_CONNECTION_TIMEOUT:TimeInterval = 5
    let TCP_CONNECTION_TIMEOUT:TimeInterval = 600 //HTTP_CONNECTIPN_TIMEPUT*6
    let HTTPS_CONNECTION_TIMEOUT:TimeInterval = 60//HTTP_CONNECTIPN_TIMEPUT*3
    let vpn_status_timer_second = 1.0
    
    let RECENT_REQUEST_LENGTH:Int = 20
    let SOCKET_DELAY_READ: TimeInterval = 0.050
    let SFTCPManagerEnableDropTCP = false
    let LimitTCPConnectionCount_DELAY:Int = 0
    let LimitTCPConnectionCount:Int = 10
    let LimitTCPConnectionCount_DROP:Int = 15
    let TCP_DELAY_START = 0.5
    let LimitMemoryUsed:UInt = 13000000//15*1024*1024 //15MB
    let LimitStartDelay:Int = 10 //10 second
    //let BUF_SIZE:size_t = 2048
    let LimitSpeedSimgle:UInt = 100*1024 //1KB/ms
    let LimitLWIPInputSpeedSimgle:UInt = 3*1024 //1KB/ms
    var memoryLimitUesedSize:UInt = 1*1024*1024
    let physicalMemorySize = physicalMemory()
    let LimitSpeedTotal:UInt = 20*1024*1024//LimitSpeedSimgle //1MB/s
}
