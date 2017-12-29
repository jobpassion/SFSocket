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

    func prepare(){
        SKit.proxyIpAddr = "240.7.1.10"
       
        SKit.dnsAddr = "218.75.4.130"
        SKit.proxyHTTPSIpAddr = "240.7.1.11"
        SKit.xxIpAddr = "240.7.1.12"
        SKit.tunIP = "240.7.1.9"
        if  !SKit.prepare("745WQDK4L7.com.yarshure.Surf"){
            fatalError()
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        prepare()
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

