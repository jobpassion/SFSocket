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
class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        testsnappy()
        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
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

}

