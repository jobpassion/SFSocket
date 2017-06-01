//
//  STNetworkInterfaceManager.swift
//  SimpleTunnel
//
//  Created by yarshure on 15/11/11.
//  Copyright © 2015年 Apple Inc. All rights reserved.
//

import Foundation

import AxLogger
func getIFAddresses() -> [NetInfo] {
    let addresses = [NetInfo]()
    return addresses
}
public class SFNetworkInterfaceManager: NSObject {
    
     static public var defaultIPAddress:String = ""
     static public var WiFiIPAddress:String = ""
     static public var WWANIPAddress:String = ""
    
      static   var networkInfo:[NetInfo] = []
    


     static public  func updateIPAddress(){
        SKit.log("clear ipaddress",level: .Info)
//        WiFiIPAddress  = ""
//        WWANIPAddress = ""
        networkInfo  = getIFAddresses()
        //en1 pdp_ip1
        for info in networkInfo{
            if info.ifName.hasPrefix("en"){
                WiFiIPAddress = info.ip
            }
            
            if info.ifName.hasPrefix("pdp_ip"){
                WWANIPAddress = info.ip
            }
        }
        
        if SFEnv.hwType == .wifi {
            defaultIPAddress = WiFiIPAddress
        }else if  SFEnv.hwType == .cell {
            defaultIPAddress = WWANIPAddress
        }

        SKit.log("Now default IPaddr \(defaultIPAddress)",level: .Info)
        SKit.log("WI-FI:\(WiFiIPAddress) CELL:\(WWANIPAddress)",level: .Info)
        SFEnv.updateEnvIP(defaultIPAddress)
        showRouter()
        
    }
 
     static public  func showRouter() {
//                dispatch_async(dispatch_get_main_queue()){
//                    let routers = currntRouter()
//                    SKit.log("router IPV4 \(routers)")
//                }
//        
//                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
//                    let routers = currntRouter()
//                    SKit.log("router IPV4 \(routers)",level: .Info)
//                }
    }
     static public  func interfaceMTUWithName(_ name:String) ->Int {
        return 1500
    }
    deinit {
    }
}
