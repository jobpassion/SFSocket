//
//  ViewController.swift
//  OSXTest
//
//  Created by yarshure on 2017/6/5.
//  Copyright © 2017年 Kong XiangBo. All rights reserved.
//

import Cocoa
import SFSocket

import ObjectMapper
import Xcon
import XRuler
class ViewController: NSViewController {

    var tunManager = Tunmanager()
    
    @IBOutlet weak var memoryUsed: NSTextField!
    
    func testHTTP(){
        let x = "http,192.168.11.131,8000,,"
        if let p = SFProxy.createProxyWithLine(line: x, pname: "CN2"){
            
            _  = ProxyGroupSettings.share.addProxy(p)
        }
    }
    func prepare(){
        SKit.proxyIpAddr = "240.7.1.10"
        SKit.debugEnable = true
        SKit.dnsAddr = "218.75.4.130"
        SKit.proxyHTTPSIpAddr = "240.7.1.11"
        SKit.xxIpAddr = "240.7.1.12"
        SKit.tunIP = "240.7.1.9"
        Xcon.debugEnable = true
        
       
        if  !SKit.prepare("745WQDK4L7.com.yarshure.Surf", app: "VPNTest", config:"abigt.conf" ){
            fatalError()
        }
        if let x = SFSettingModule.setting.findRuleByString("www.google.com", useragent: ""){
            print(x)
        }
        testHTTP()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        prepare()
        _ = tunManager.open()
//        testaead()
//        testsnappy()
        
        
        // Do any additional setup after loading the view.
    }

    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    


 
}

