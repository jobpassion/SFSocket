//
//  ViewController.swift
//  VPNTest
//
//  Created by yarshure on 2018/1/3.
//  Copyright © 2018年 Kong XiangBo. All rights reserved.
//

import Cocoa
import SFSocket
import XRuler

class ViewController: NSViewController {
    let server:ServerTunnelConnection = ServerTunnelConnection.shared
    func prepare() {
        //XRuler.groupIdentifier =
        SKit.proxyIpAddr = "240.7.1.10"
        
        SKit.dnsAddr = "218.75.4.130"
        SKit.proxyHTTPSIpAddr = "240.7.1.11"
        SKit.xxIpAddr = "240.7.1.12"
        SKit.tunIP = "240.7.1.10"
        SFSettingModule.setting.mode = .socket
        XRuler.kProxyGroupFile = ".ProxyGroup"
        if !SKit.prepare("group.com.yarshure.Surf", configPath: "xxxx"){
            fatalError("framework init error!")
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        prepare()
        server.tunnel = Tunnel()
        _ = server.open()
        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

