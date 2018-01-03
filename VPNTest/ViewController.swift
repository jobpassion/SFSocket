//
//  ViewController.swift
//  VPNTest
//
//  Created by yarshure on 2018/1/3.
//  Copyright © 2018年 Kong XiangBo. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    let server:ServerTunnelConnection = ServerTunnelConnection()
    override func viewDidLoad() {
        super.viewDidLoad()

        server.tunnel = Tunnel()
        server.open()
        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

