//
//  ViewController.swift
//  SFSocketTest
//
//  Created by 孔祥波 on 16/11/2016.
//  Copyright © 2016 Kong XiangBo. All rights reserved.
//

import UIKit
import SFSocket
import ObjectMapper
import snappy
import CommonCrypto
extension String{
    //: ### Base64 encoding a string
    func base64Encoded() -> String? {
        if let data = self.data(using: .utf8) {
            return data.base64EncodedString()
        }
        return nil
    }
    
    //: ### Base64 decoding a string
    func base64Decoded() -> String? {
        if let data = Data(base64Encoded: self) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}
class ViewController: UIViewController {
    let q = DispatchQueue.init(label: "com.yarshure.test")
    var data = Data()
    var http:HTTPTester?
   
    override func viewDidLoad() {
        super.viewDidLoad()
//        Frame.testframe()
//         testsnappy()
//        let _:Float = 10.23
        let iv = "This is an IV456" // should be of 16 characters.
        //here we are convert nsdata to String
        let encryptedString = "YFAz+BYqSpawy3FK52MFgw=="
        let ss = SSEncrypt.init(password:"This is a key123This is an IV456" , method: "aes-256-cfb",ivsys: iv)
        
        guard  let xx = ss.encrypt(encrypt_bytes: "The answer is no".data(using: .utf8)!) else {
            return
        }
        print(xx as NSData)
        print("****")
        let sub = xx.subdata(in: 16..<xx.count-1)
        let pwd  = sub.base64EncodedString()
        var data = iv.data(using: .utf8)!
        data.append(Data(base64Encoded: pwd)!)

        if let passwd = ss.decrypt(encrypt_bytes: xx){
            print(passwd as NSData)
            print(String.init(data: passwd, encoding: .utf8)!)
        }
        //now we are decrypting
        
//        if let decryptedString = encryptedString.aesDecrypt(key: , iv: iv) // 32 char pass key
//        {
//            // Your decryptedString
//            print(decryptedString)
//        }
        testaead()
//        print(String.init(format: "%.0f", a))
//        
//        if let h = SFHTTPHeader.init(data: http503.data(using: .utf8)!){
//            print(h.app)
//        }
//        if  let b = SFHTTPRequestHeader.init(data: http503.data(using: .utf8)!){
//            print(b.Host)
//        }
//        if  let b = SFHTTPResponseHeader.init(data: http503.data(using: .utf8)!){
//            print(b.sCode)
//        }
//        Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(ViewController.test(_:)), userInfo: nil, repeats: true)
        // Do any additional setup after loading the view, typically from a nib.
       
    }
    func testxx(){
      
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
    func test(_ t:Timer) {
        
        
        q.async {
            let t  = Date()
            autoreleasepool(invoking: {
                
                
                let enc = SSEncrypt.init(password: "aes-256", method: "chacha20")
                //for _ in 0 ..<  10000 {
                
                let st = "sdlfjlsadfjalsdjfalsdfjlasf"
                let data = st.data(using: .utf8)!
                for _ in 0 ..< 10 {
                    let out  = enc.encrypt(encrypt_bytes: data)
                    //                result.append(out!)
                    //                let x = enc.decrypt(encrypt_bytes: out!)
                    print(out! as NSData)
                    let d2 = enc.decrypt(encrypt_bytes: out!)
                    
                    let str = String.init(data: d2!, encoding: .utf8)
                    if str == st {
                        print("test pass")
                    }
                    print("\(str!)")
                }
                
                DispatchQueue.main.async {[weak self] in
                    //self!.update(out!)
                }
                // usleep(5000)
                //}
                let tw = Date().timeIntervalSince(t)
                print(tw)
                
            })
            //usleep(500)
           
        }
        
    }
    func fin() {
        print(data.count)
       
        print(data as NSData)
    }
    func update(_ d:Data){
        if data.count != 0 {
            data.removeAll(keepingCapacity: true)
        }
        data.append(d)
        
    }
    @IBAction func testEncrypt(_ sender: Any) {
        //test()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
            self.http = HTTPTester.init(p: p)
            self.http?.start()
            
        }
        //var config = KCPTunConfig()
        //let pass = config.pkbdf2Key(pass: p.key, salt: "kcp-go".data(using: .utf8)!)
        //print("\(pass as! NSData)")
        //print(ProxyGroupSettings.share.proxys)
        
    }
}

