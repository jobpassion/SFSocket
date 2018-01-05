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
import Xcon
import AxLogger
class ViewController: NSViewController {
    let server = VPNServer()
    func prepare() {
        let d = SFEnv.session.startTime
       
        SKit.proxyIpAddr = "240.7.1.9"
        SKit.dnsAddr = "218.75.4.130"
        SKit.proxyHTTPSIpAddr = "240.7.1.11"
        SKit.xxIpAddr = "240.7.1.12"
        SKit.tunIP = "240.7.1.9"
        SFSettingModule.setting.mode = .socket
        XRuler.kProxyGroupFile = ".ProxyGroup"

    
        
        if  !SKit.prepare("745WQDK4L7.com.yarshure.Surf", app: "VPNTest", config: "abigt.conf"){
            fatalError()
        }
        if let x = SFSettingModule.setting.findRuleByString("www.google.com", useragent: ""){
            print(x)
        }
        ProxyGroupSettings.share.historyEnable = true
        if ProxyGroupSettings.share.historyEnable {
            
            let helper = RequestHelper.shared
            let session = SFEnv.session.idenString()
            let x = d.timeIntervalSince1970
            
            helper.open( session,readonly: false,stamp: x)
        }
        
       
       
        
        AxLogger.log("VPN SESSION starting",level: .Info)
        testHTTP()
    }
    func testHTTP(){
        let x = "http,192.168.11.131,8000,,"
        if let p = SFProxy.createProxyWithLine(line: x, pname: "CN2"){
            
            _  = ProxyGroupSettings.share.addProxy(p)
        }
        
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        prepare()
        
        server.start()

//        server.tunnel = Tunnel()
//        _ = server.open()
        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

