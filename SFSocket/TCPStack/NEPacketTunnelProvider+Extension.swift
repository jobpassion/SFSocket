//
//  NEPacketTunnelProvider+Extension.swift
//  SFSocket
//
//  Created by 孔祥波 on 07/04/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//

import Foundation
import NetworkExtension
extension NEPacketTunnelProvider{
    func alert(message:String,reason:NEProviderStopReason){
        if #available(iOSApplicationExtension 10.0, *) {
            //VPN can alert
            if reason != .userInitiated {
                if #available(OSXApplicationExtension 10.12, *) {
                    displayMessage(message, completionHandler: { (fin) in
                        
                    })
                } else {
                    // Fallback on earlier versions
                }
            }
            
        }
        
    }
    
}
