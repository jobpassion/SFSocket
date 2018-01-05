//
//  VPNServer.swift
//  VPNTest
//
//  Created by yarshure on 2018/1/4.
//  Copyright © 2018年 Kong XiangBo. All rights reserved.
//

import Foundation

func ignore(_: Int32)  {
}


class VPNServer {
    /// Dispatch source to catch and handle SIGINT
    let interruptSignalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: DispatchQueue.main)
    /// Dispatch source to catch and handle SIGTERM
    let termSignalSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: DispatchQueue.main)
    func start(){
        signal(SIGTERM, ignore)
        signal(SIGINT, ignore)
        let portString = "8890"
        let configurationPath = Bundle.main.path(forResource: "config.plist", ofType: nil)
        let networkService: NetService
        
        // Initialize the server.
        
        if !ServerTunnel.initializeWithConfigurationFile(path: configurationPath!) {
            exit(1)
        }
        
        if let portNumber = Int(portString)  {
            networkService = ServerTunnel.startListeningOnPort(port: Int32(portNumber))
        }
        else {
            print("Invalid port: \(portString)")
            exit(1)
        }
        
        // Set up signal handling.
        
        interruptSignalSource.setEventHandler() {
            networkService.stop()
            return
        }
        interruptSignalSource.resume()
        
        termSignalSource.setEventHandler {
            networkService.stop()
            return
        }
        termSignalSource.resume()
        
    }
}
