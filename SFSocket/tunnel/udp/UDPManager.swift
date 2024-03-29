//
//  UDPManager.swift
//  SFSocket
//
//  Created by yarshure on 2018/1/3.
//  Copyright © 2018年 Kong XiangBo. All rights reserved.
//

import Foundation
import NetworkExtension
import XProxy
public class UDPManager {
    
    public let udpStack = UDPDirectStack()
    public var clientTree:AVLTree = AVLTree<UInt16,SFUDPConnector>()
    public  var udpClientIndex:[UInt16] = []
    public func indexFor(port:UInt16) ->Int {
        for (n,c) in udpClientIndex.enumerated() {
            if c == port {
                return n
            }
            
        }
        return -1
    }
    init() {
        //todo
//        if let p = SKit.packettunnelprovier {
//            udpStack.outputFunc = p.generateOutputBlock()
//        }
       
    }
    public func cleanUDPConnector(force:Bool){
        if force {
            for (_,c) in udpClientIndex.enumerated() {
                if let x = clientTree.search(input: c) {
                    x.shutdownSocket()
                }
                clientTree.delete(key: c)
            }
            udpClientIndex.removeAll()
        }else {
            var tomove:[Int] = []
            for (n,c) in udpClientIndex.enumerated() {
                if  let cc = clientTree.search(input: c) {
                    if Date().timeIntervalSince(cc.activeTime) > 5.0 {
                        if let x = clientTree.search(input: c) {
                            x.shutdownSocket()
                        }
                        clientTree.delete(key: c)
                        tomove.append(n)
                        
                    }
                    
                }
                
            }
            for i in tomove.reversed() {
                udpClientIndex.remove(at: i)
            }
        }
    }
    public func serverDidClose(_ targetTunnel: SFUDPConnector){
        
        let c = targetTunnel as! SFDNSForwarder
        let srcport = c.clientPort
        clientTree.delete(key: srcport)
        let index:Int = indexFor(port: srcport)
        if index != -1 {
            udpClientIndex.remove(at: index)
        }
        c.shutdownSocket()
        
    }
    public func serverDidQuery(_ targetTunnel: SFUDPConnector, data : Data,close:Bool){
        
        
        if data.count > 0 {
            let c = targetTunnel as! SFDNSForwarder
            let srcport = c.clientPort
            if close {
                c.shutdownSocket()
                SKit.log("delete \(srcport) udp connect", level: .Info)
                clientTree.delete(key: srcport)
                let index:Int = indexFor(port: srcport)
                if index != -1 {
                    udpClientIndex.remove(at: index)
                }
                
                
            }else {
                SKit.log("\(srcport) udp connect living", level: .Info)
            }
            cleanUDPConnector(force: false)
            
        }
    }
}
