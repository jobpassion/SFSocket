//
//  ViewController.swift
//  OSXTest
//
//  Created by yarshure on 2017/6/5.
//  Copyright © 2017年 Kong XiangBo. All rights reserved.
//

import Cocoa
import SFSocket
import snappy
import ObjectMapper
class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        testaead()
        testsnappy()
        testServer()
        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    func testServer(){
        SFTCPConnectionManager.manager.startGCDServer()
    }
    func testsnappy(){
        let st = "sdlfjlsadfjalsdjfalsdfjlasf".data(using: .utf8)!
        
        
        
        let count:UnsafeMutablePointer<Int> = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        count.pointee =  snappy_max_compressed_length(st.count)
        let out:UnsafeMutablePointer<Int8> = UnsafeMutablePointer<Int8>.allocate(capacity: count.pointee)
        defer {
            out.deallocate(capacity: count.pointee)
            count.deallocate(capacity: 1)
            
        }
        st.withUnsafeBytes { (input: UnsafePointer<Int8>) -> Void in
            if snappy_compress(input, st.count, out, count) == SNAPPY_OK {
                print("ok \(count.pointee)")
            }
        }
        print(out)
        print("src \(st as NSData)")
        
        //let raw = UnsafeRawPointer.init(out)
        let result = Data(buffer: UnsafeBufferPointer(start:out,count:count.pointee))
        print("out \(count.pointee) \(result as NSData)")
        testDecomp(st, mid: result)
    }
    func testDecomp(_ src:Data,mid:Data){
        let count:UnsafeMutablePointer<Int> = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        count.pointee =  snappy_max_compressed_length(mid.count)
        let out:UnsafeMutablePointer<Int8> = UnsafeMutablePointer<Int8>.allocate(capacity: count.pointee)
        defer {
            out.deallocate(capacity: count.pointee)
            count.deallocate(capacity: 1)
            
        }
        
        mid.withUnsafeBytes { (input: UnsafePointer<Int8>) -> Void in
            if snappy_uncompress(input, mid.count, out, count) == SNAPPY_OK {
                print("ok \(count.pointee)")
            }
        }
        let result = Data(buffer: UnsafeBufferPointer(start:out,count:count.pointee))
        print("out \(count.pointee) \(result as NSData)")
        
    }

    func testaead(){
        let lengString = String(repeating: "AAA", count: 4)
        print(lengString)
        _ = AEADCrypto.init(password: "aes-256", key: "", method: "aes-256-gcm")
        //enc.testGCM()
        let x:[UInt8] = [0x61,0x62,0x63,0x64,0x65,0x66,0x67,0x68]
        let data:rawHeader = Data.init(bytes: x)
        //print(data.desc())
        //print(ProxyGroupSettings.share.proxys)
        guard let p = Mapper<SFProxy>().map(JSONString: "{\"type\":0}") else {
            return
        }
        _ = ProxyGroupSettings.share.addProxy(p)
        //let line = " https,office.hshh.org,51001,vpn_yarshure,kong3191"
        let kcptun = "http,192.168.11.8,6000,,"
        if let p = SFProxy.createProxyWithLine(line: kcptun, pname: "CN2"){
            //_ = ProxyGroupSettings.share.addProxy(p)
            p.kcptun = true
            p.serverIP = "192.168.11.8"
            _  = ProxyGroupSettings.share.addProxy(p)
            p.config.crypt = "none"
            print(p.base64String())
            //self.http = HTTPTester.init(p: p)
            //self.http?.start()
            
        }
        //var config = KCPTunConfig()
        //let pass = config.pkbdf2Key(pass: p.key, salt: "kcp-go".data(using: .utf8)!)
        //print("\(pass as! NSData)")
        //print(ProxyGroupSettings.share.proxys)
        
    }
}

