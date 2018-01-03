//
//  TestVC.swift
//  SFSocket
//
//  Created by yarshure on 2017/8/30.
//  Copyright © 2017年 Kong XiangBo. All rights reserved.
//

import Cocoa
import SFSocket
class TestVC: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        
        SKit.startGCDProxy(port: 10081)
        
    }
    
}
