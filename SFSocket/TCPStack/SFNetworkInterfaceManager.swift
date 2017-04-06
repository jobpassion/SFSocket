//
//  STNetworkInterfaceManager.swift
//  SimpleTunnel
//
//  Created by yarshure on 15/11/11.
//  Copyright © 2015年 Apple Inc. All rights reserved.
//

import Foundation

import AxLogger
class SFNetworkInterfaceManager: NSObject {
    
    var defaultIPAddress:String = ""
    var WiFiIPAddress:String = ""
    var WWANIPAddress:String = ""
    
    var networkInfo:[NetInfo] = []
    static let instances = SFNetworkInterfaceManager()
//    static func sharedInstance() ->STNetworkInterfaceManager {
//        return instances
    
//    }
    override init() {
//        do {
//           
//        } catch {
//            print("Unable to create Reachability")
//            //return
//        }
        super.init()
        //monitor()
    }
    func updateIPAddress(){
        AxLogger.log("clear ipaddress",level: .Info)
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
        
        if SFEnv.env.hwType == .wifi {
            defaultIPAddress = WiFiIPAddress
        }else if  SFEnv.env.hwType == .cell {
            defaultIPAddress = WWANIPAddress
        }

        AxLogger.log("Now default IPaddr \(defaultIPAddress)",level: .Info)
        AxLogger.log("WI-FI:\(WiFiIPAddress) CELL:\(WWANIPAddress)",level: .Info)
        SFEnv.env.updateEnvIP(defaultIPAddress)
        showRouter()
        
    }
 
    func showRouter() {
//                dispatch_async(dispatch_get_main_queue()){
//                    let routers = currntRouter()
//                    AxLogger.log("router IPV4 \(routers)")
//                }
//        
//                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
//                    let routers = currntRouter()
//                    AxLogger.log("router IPV4 \(routers)",level: .Info)
//                }
    }
    func interfaceMTUWithName(_ name:String) ->Int {
        return 1500
    }
    deinit {
    }
}
