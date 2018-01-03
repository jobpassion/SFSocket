//
//  Tunnel.swift
//  OSXTest
//
//  Created by yarshure on 2018/1/3.
//  Copyright © 2018年 Kong XiangBo. All rights reserved.
//

import Foundation

class Tunnel {
    /// The maximum size of a single tunneled IP packet.
    class var packetSize: Int { return 8192 }
    /// The maximum number of IP packets in a single SimpleTunnel data message.
    class var maximumPacketsPerMessage: Int { return 32 }
    /// Send a Packets message on the tunnel connection.
    func sendPackets(_ packets: [Data], protocols: [NSNumber], forConnection connectionIdentifier: Int){
        
        simpleTunnelLog("receive \(packets)")
    }
}
