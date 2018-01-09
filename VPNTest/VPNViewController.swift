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
import XSocket
class VPNViewController: NSViewController {
    let server = VPNServer()
    var timer:DispatchSourceTimer!
     @IBOutlet weak var memoryUsedLabel: NSTextField!
    override func viewDidLoad() {
        super.viewDidLoad()
        //prepare()
     

//        server.tunnel = Tunnel()
//        _ = server.open()
        // Do any additional setup after loading the view.
    }
    func updateUI() {
        memoryUsedLabel.objectValue = memoryUsed()
    }
    @IBAction func AddProxy(_ sender: Any) {
        let x = "http,192.168.11.131,8000,,"
        if let p = SFProxy.createProxyWithLine(line: x, pname: "CN2"){
            
            _  = ProxyGroupSettings.share.addProxy(p)
        }
    }
    func startTimer(){
        timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        
        timer.schedule(deadline: DispatchTime.distantFuture , repeating: DispatchTimeInterval.microseconds(1000), leeway: DispatchTimeInterval.microseconds(1000))
        timer.setEventHandler {
            [weak self] in
            self!.updateUI()
        }
        
        timer.resume()
        
    }
    @IBAction func prepareEvn(_ sender: Any) {
        //500+ KB memory
        startTimer()
        Xcon.debugEnable = true
        Xsocket.debugEnable = true
        SKit.debugEnable = true
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
        SKit.startGCDProxy(port: 10081, dispatchQueue: DispatchQueue.main, socketQueue: DispatchQueue.init(label: "com.yarshure.socket"))
        print("runing ,..")
    }
    @IBAction func startServert(_ sender: Any) {
        //12KB
        server.start()
    }
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

