//
//  SFFunc.swift
//  Surf
//
//  Created by 孔祥波 on 16/1/15.
//  Copyright © 2016年 yarshure. All rights reserved.
//

import Foundation
#if os(iOS)
import UIKit
    #endif
//func version() -> Int {
//    return ProcessInfo.processInfo.operatingSystemVersion.majorVersion
//    
//}
var lastmemory:UInt = 0
var log_ENABLE_REOPEN = true
func checkJB() ->Bool{
    return fm.fileExists(atPath: "/private/var/lib/apt/")
           // NSFileManager * fileManager = [NSFileManager defaultManager];
           // return [fileManager fileExists(atPath::@"/private/var/lib/apt/"];
    //}
}
func appInfo() -> [String:String]{
    var result = [String:String]()
    if let info = Bundle.main.infoDictionary, let appVersion =  info["CFBundleShortVersionString"] as? String,let buildVersion =  info["CFBundleVersion"] as? String {
        result["appVersion"] =  appVersion
        result["buildVersion"] = buildVersion
        
    }
    #if os(iOS)
    result["mode"] = UIDevice.current.model
    result["platform"] = ""// hwVersion()
    #endif
    result["memory"] = "\(physicalMemory())G"
    result["iOS"] = ProcessInfo.processInfo.operatingSystemVersionString
    if checkJB(){
         result["jb"] = "yes"
    }else {
        result["jb"] = "no"
    }
    
    return result
}



func appVersion() -> String{
    if let info = Bundle.main.infoDictionary, let appVersion =  info["CFBundleShortVersionString"] as? String{
        return appVersion
    }
    return ""
}
func appBuild() -> String{
    if let info = Bundle.main.infoDictionary, let buildVersion =  info["CFBundleVersion"] as? String{
        return buildVersion
    }
    return ""
}
func physicalMemory() ->Int{
    let memory = ProcessInfo.processInfo.physicalMemory
    let gb:UInt64 = 1024*1024*1024
    if memory < gb {
        return 1
    }else if memory > gb && memory < gb*2 {
        return 2
    }else if memory > 2*gb && memory < gb*3 {
        return 3
    }else if memory > 3*gb && memory < gb*4 {
        return 4
    }
    return 1
}

func debugLog(_ message:String){
    #if DEBUG
//        if  message.range(of:"%") == nil{
//            NSLog(message)
//        }else {
//            NSLog("debugLog message have %")
//        }

        
        //debugPrint(message)
    #endif
}

public func mylog<T>(_ object: T, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
    //let fn = file.split { $0 == "/" }.last
    let fn = file.characters.split { $0 == "/" }.map(String.init).last
    if let f = fn {
        let info = "\(f) \(function)[\(line)]:\(object)"
        NSLog(info)
        //debugPrint(info)
        //print(info,errStream)
        //print()
        //print(info, StderrStream.shared)
    }else {
        let info = "\(file) [\(line)]:\(object)"
        //debugPrint(info)
        NSLog(info)
        //print(info,errStream)
        //print(info, toStream: &StderrStream.shared)
    }
    //    let info = "\(function):\(object)"
    //    NSLog(info)
}
func logURL(_ date:Date) ->String {
    //let date = NSDate()
    let df = DateFormatter()
    df.dateFormat = "yyyy_MM_dd_HH_mm_ss"
    let string = df.string(from: date)
    createLogDir()
    let url = groupContainerURL().appendingPathComponent("Log/\(string).log")
    return url.path
    
}
func createLogDir(){
    
    let logU = groupContainerURL().appendingPathComponent("Log/")
    let x = logU.path
    if !fm.fileExists(atPath: x) {
        do {
            try  fm.createDirectory(at: logU, withIntermediateDirectories: true, attributes: nil)
        } catch let e  {
            print(e.localizedDescription)
        }
    }
    
    
}
//func SFFatfatalError(message:String,) {
//    fatalError(message,file:"",)
//
//}
class OutputStream: OutputStreamType {
    var stream: UnsafeMutablePointer<FILE> // Target stream
    var path: String? = nil // File path if used
    var dataformater = DateFormatter()
    // Create with stream
    public init(_ stream: UnsafeMutablePointer<FILE>) {
        self.stream = stream
    }
    
    // Create with output file
    public init( p: String, append: Bool = false) {
        path = (p as NSString).expandingTildeInPath
        if append {
            stream = fopen(path!, "a")
        } else {
            stream = fopen(path!, "w")
        }
        dataformater.dateFormat = "HH:mm:ss.SSS"
        self.path = p
        
    }
    
    // stderr
    open static func stderr() -> OutputStream {
        return OutputStream(Darwin.stderr)
    }
    
    // stdout
    open static func stdout() -> OutputStream {
        return OutputStream(Darwin.stdout)
    }
    
    // Conform to OutputStreamType
    open func write(_ string: String) {
        let d = Date()
        fputs("\(dataformater.string(from: d)) ", stream)
        fputs(string, stream)
        fputs("\n", stream)
        fflush(stream)
    }
    open func reopen() {
        fclose(stream)
        let cpath = logURL(Date())
        let p = (cpath as NSString).expandingTildeInPath
        
        stream = fopen(p, "w")
        
    }
    // Clean up open FILE
    deinit {
        if path != nil {fclose(stream)}
    }
}

// Pre-built instances
//public var errStream = OutputStream.stderr()
//public var stdStream = OutputStream.stdout()
//public var logStream = OutputStream.init(p: logURL(NSDate()), append: true)
protocol OutputStreamType {
    /// Append the given `string` to this stream.
    mutating func write(_ string: String)
}
func copyFile(_ src:URL,dst:URL,forceCopy:Bool) throws{
    let spath = src.path
    let dpath = dst.path
    if fm.fileExists(atPath: dpath)   {
    
        if forceCopy{
            do {
                try fm.removeItem(atPath: dpath)
                
            }catch let error as NSError{
                throw error
            }
            
            do {
                try fm.copyItem(atPath: spath, toPath: dpath)
            }catch let error as NSError{
                throw error
            }
        }
        
    }else {
        do {
            try fm.copyItem(atPath: spath, toPath: dpath)
        }catch let error as NSError{
            throw error
        }
    }
    
    
    
}

let  applicationDocumentsDirectory: URL = {
    // The directory the application uses to store the Core Data store file. This code uses a directory named "com.yarshuremac.test" in the application's documents Application Support directory.
    let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return urls[urls.count-1]
}()

//func toIPv6Addr(ipString:String) -> Data?  {
//    var addr = in6_addr()
//    let retval = withUnsafeMutablePointer(to: &addr) {
//        inet_pton(AF_INET6, ipString, UnsafeMutablePointer($0))
//    }
//    if retval < 0 {
//        return nil
//    }
//    
//    let data = NSMutableData.init(length: 16)
//    let p = UnsafeMutableRawPointer.init(mutating: (data?.bytes)!)
//    //let addr6 =
//    //#if swift("2.2")
//    //memcpy(p, &(addr.__u6_addr), 16)
//    memcpy(p, &addr, 16)
//    //#else
//    //#endif
//    //print(addr.__u6_addr)
//    return data as Data?
//}
 func very(ip:String) ->Bool{
    if ip.characters.count > 15 {
        return false
    }
    let x = ip.components(separatedBy: ".")
    if x.count != 4 {
        return false
    }else {
        for item in x {
            if let x = Int(item) {
                if x<0 || x>255{
                    return false 
                }
            }else {
                return false
            }
        }
    }
    //        for d in x {
    //            Int(x)
    //        }
    return true
}



let SOCKS_VERSION:UInt8 = 0x05
let SOCKS_AUTH_VERSION:UInt8 = 0x01
let SOCKS_AUTH_SUCCESS:UInt8 = 0x00
let SOCKS_CMD_CONNECT:UInt8 = 0x01
let SOCKS_IPV4:UInt8 = 0x01
let SOCKS_DOMAIN :UInt8 = 0x03
let SOCKS_IPV6:UInt8 = 0x04
let SOCKS_CMD_NOT_SUPPORTED :UInt8 = 0x07

struct method_select_request
{
    var ver:UInt8
    var nmethods:UInt8
    //char methods[255];
    var methods:Data
}

struct method_select_response
{
    var ver:UInt8
    var method:UInt8
}

struct socks5_request
{
    var ver:UInt8
    var cmd:UInt8
    var rsv:UInt8
    var atyp:UInt8
}

struct socks5_response
{
    var ver:UInt8
    var rep:UInt8
    var rsv:UInt8
    var atyp:UInt8
}
