//
//  SFPacketTunnelProvider.swift
//  SFSocket
//
//  Created by yarshure on 2018/2/11.
//  Copyright © 2018年 Kong XiangBo. All rights reserved.
//

import Foundation
import NetworkExtension
import XRuler
import AxLogger
func writePathFromFile(_ path:String) ->Bool{
    let url = applicationDocumentsDirectory.appendingPathComponent("groupContainerURLVPN")
    do {
        try path.write(toFile: url.path, atomically: true, encoding: String.Encoding.utf8)
        // try path.writeToURL(url, atomically: true, encoding: NSUTF8StringEncoding)
    }catch _ {
        return false
    }
    return true
    
}
func readPathFromFile() ->String {
    let url = applicationDocumentsDirectory.appendingPathComponent("groupContainerURLVPN")
    do {
        let s = try String.init(contentsOf: url, encoding: .utf8)
        return s
    }catch _{
        
    }
    return ""
}
open  class SFPacketTunnelProvider: NEPacketTunnelProvider {

    
    var pendingStartCompletion:((Error?) ->Void)?
    
    //var stopCompletionHandler: () -> Void)
    var pendingStopCompletion:(() -> Void)?
    var lastPath:NWPath?
    var startTimes = 0
    
    override init() {
        
        NSLog("init ################1111")
        
        
        super.init()
        
        
        
    }
    
    
    
    func prepareTunnelNetworkSettings(_ reset:Bool){//(NSError?) -> Void)
        
        
        
        
        SKit.prepareTunnel(provier: self, reset: reset) { (error) in
            
            
            if let error = error {
                
                
                SKit.log(" \(error.localizedDescription)",level: .Error)
            }
            else {
                // Now we can start reading and writing packets to/from the virtual interface.
                //AxLogger.log("start process packets",level: .Warning)
                if !self.reasserting{
                    self.vpnStartFinish()
                    
                }else {
                    SKit.log("VPN exit reasserting...", level: .Warning)
                    self.reasserting = false
                }
                self.startHandlingPackets()
            }
            // Now the tunnel is fully established, call the start completion handler.
            
            self.pendingStartCompletion?(error)
            
            self.pendingStartCompletion = nil
        }
        
        
       
        
    }
    func vpnStartFinish() {
        
        SFTCPConnectionManager.shared.start()
        
        
        if let p = ProxyGroupSettings.share.selectedProxy{
            SKit.log("selected proxy server " + p.serverAddress + ":" + p.serverPort,level: .Info)
        }
        
        self.addObserver(self, forKeyPath: "defaultPath", options: .initial, context: nil)
    }
    override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if let path = keyPath,  path == "defaultPath"{
            
            if let d = self.defaultPath {
                
                if  self.lastPath ==  nil {
                    
                    if d.isExpensive {
                        SKit.log("#### init NWPath Cell and get IPAddress",level: .Info)
                    }else {
                        SKit.log("#### init NWPath WI-FI and get IPAddress",level: .Info)
                    }
                    SFNetworkInterfaceManager.updateIPAddress(d)
                    self.lastPath = d
                    return
                }else {
                    // AxLogger.log("#### lastPath \(d.info)",level: .Warning)
                    if  let l = self.lastPath {
                        if l.isExpensive != d.isExpensive{
                            
                            networkchanged()
                            
                        }else {
                            if !d.isEqual(to: d)  {
                                networkchanged()
                            }else {
                                SKit.log("#### NWPath  equal",level: .Warning)
                            }
                            
                        }
                    }else {
                        SKit.log("#### lastPath nil",level: .Warning)
                    }
                    self.lastPath = d
                    
                }
                
            }else {
                SKit.log("#### defaultPath nil",level: .Warning)
            }
            
            
        }else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change , context: context)
        }
    }
    
    func networkchanged() {
        
        
        if reasserting == false {
            
            SFTCPConnectionManager.shared.cleanConnection()
            SFSettingModule.setting.cleanDNSCache()
            
            reasserting = true
            SKit.log("VPN session reasserting now",level: .Info)
            setTunnelNetworkSettings(nil) { [unowned self ] error in
                //还会激发一次网络变得
                if let error = error {
                    AxLogger.log("clear settings error \(error.localizedDescription)",level: .Error)
                }else {
                    if let path = self.lastPath  {
                        
                        SKit.log("will exit reasserting \(path.status) ",level: .Info)
                        self.asyncStartService(3)
                    }
                    
                }
                
            }
        }else {
            AxLogger.log("VPN session reasserting...",level: .Info)
            if let path = self.lastPath  {
                //Thread.sleep(forTimeInterval: 0.5)
                if path.status == .satisfied {
                    asyncStartService(3)
                }else {
                    SKit.log("Not Satisfied pauseing...",level: .Info)
                }
            }else {
                guard let p = self.defaultPath else {return}
                if  p.status == .satisfied {
                    asyncStartService(3)
                }else {
                    SKit.log("Not Satisfied pauseing...",level: .Info)
                }
            }
            
        }
        
    }
    
    func asyncStartService(_ sec:Int){
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(sec), execute: {
            self.prepareTunnelNetworkSettings(false)
            self.reasserting = false
        })
    }
    public func start(options: [String : NSObject]? = nil, completionHandler: @escaping (Error?) -> Void) {
        
        
        let session = SFEnv.session.startTime
        
        if let o = options {
            if let p = o["kPath"]{
                groupContainerURLVPN = p as! String
                _ = writePathFromFile(groupContainerURLVPN)
            }else {
                groupContainerURLVPN = readPathFromFile()
            }
            if let c  = o["kConfig"] {
                let config = c as! String
                if config != ProxyGroupSettings.share.config {
                    ProxyGroupSettings.share.config = config
                }
            }
            
        }
        let url  = groupContainerURL()
        
        
        #if DEBUG
            AxLogger.openLogging(url, date: session,debug: true)
            SKit.log("Debug Log enabled", level: .Info)
        #else
            AxLogger.openLogging(url, date: session,debug: false)
            
        #endif
        
        
        if ProxyGroupSettings.share.historyEnable {
            
            let helper = RequestHelper.shared
            let session = SFEnv.session.idenString()
            
            
            helper.open( session,readonly: false,session: session)
        }
        
        //}
        pendingStartCompletion = completionHandler
        startTimes += 1
        prepareTunnelNetworkSettings(false)
        SKit.log("VPN SESSION starting",level: .Info)
    }
    
    override open func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        //framework should save data
        _exit(0)
        
    }
    override open func wake() {
        SKit.log("Device wake!!!",level: .Notify)
    }
    override open func sleep(completionHandler: @escaping () -> Void) {
        
        // Add code here to get ready to sleep.
        SKit.log("Device sleep!!!",level: .Notify)
        
        completionHandler()
    }
    /// Handle IPC messages from the app.
    
    override open func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        SKit.handleAppMessage(messageData, completionHandler: completionHandler)
        
    }
    
    
}
