//
//  UDPManager.swift
//  SFSocket
//
//  Created by yarshure on 2018/1/3.
//  Copyright © 2018年 Kong XiangBo. All rights reserved.
//

import Foundation
import NetworkExtension
public class UDPManager {
    static let shared = UDPManager()
    let udpStack = UDPDirectStack()
    var clientTree:AVLTree = AVLTree<UInt16,SFUDPConnector>()
     var udpClientIndex:[UInt16] = []
    func indexFor(port:UInt16) ->Int {
        for (n,c) in udpClientIndex.enumerated() {
            if c == port {
                return n
            }
            
        }
        return -1
    }
    init() {
        //todo
        if let p = SKit.packettunnelprovier {
            udpStack.outputFunc = p.generateOutputBlock()
        }
       
    }
}
