//
//  File.swift
//  Surf
//
//  Created by yarshure on 15/12/23.
//  Copyright © 2015年 yarshure. All rights reserved.
//

import Foundation
import SwiftyJSON
import ObjectMapper
public enum SFProxyType :Int, CustomStringConvertible{
    case HTTP = 0
    case HTTPS = 1
    case SS = 2
    case SS3 = 6
    case SOCKS5 = 3
    case HTTPAES  = 4
    case LANTERN  = 5
    //case KCPTUN = 7
    public var description: String {
        switch self {
        case .HTTP: return "HTTP"
        case .HTTPS: return "HTTPS"
        case .SS: return "SS"
        case .SS3: return "SS3"
        case .SOCKS5: return "SOCKS5"
        case .HTTPAES: return "GFW Press"
        case .LANTERN: return "LANTERN"
            //case .KCPTUN: return "KCPTUN"
        }
    }
}
public class Proxys:CommonModel {
    var chainProxys:[SFProxy] = []
    var proxys:[SFProxy] = []
    public override func mapping(map: Map) {
        chainProxys  <- map["chainProxys"]
        proxys <- map["proxys"]
    }
    public required init?(map: Map) {
        super.init(map: map)
        //self.mapping(map: map)
    }
    func  selectedProxy(_ selectIndex:Int ) ->SFProxy? {
        if proxys.count > 0 {
            if selectIndex >= proxys.count {
                return proxys.first!
            }
            return proxys[selectIndex]
        }
        return nil
    }
    func findProxy(_ proxyName:String,dynamicSelected:Bool,selectIndex:Int) ->SFProxy? {
        
        
        
        if proxys.count > 0  {
            
            
            var proxy:SFProxy?
            if dynamicSelected {
                proxy =   proxys[selectIndex]
                return proxy
            }
            if selectIndex < proxys.count {
                let p =  proxys[selectIndex]
                if p.proxyName == proxyName{
                    return p
                }else {
                    proxy = p
                }
                
            }
            var proxy2:SFProxy?
            for item in proxys {
                if item.proxyName == proxyName {
                    proxy2 =  item
                    break
                }
            }
            if let p = proxy2 {
                return p
            }else {
                if let p = proxy {
                    return p
                }
            }
            
        }
        
        
        
        if proxys.count > 0 {
            return proxys.first!
        }
        
        
        return nil
    }
    
    public func cutCount() ->Int{
        if proxys.count <= 3{
            return proxys.count
        }
        return 3
    }
    public func removeProxy(_ Index:Int,chain:Bool = false) {
        if chain {
            chainProxys.remove(at: Index)
        }else {
            proxys.remove(at: Index)
        }
        
    }
    func changeIndex(_ srcPath:IndexPath,destPath:IndexPath){
        if srcPath.section == destPath.section {
            if srcPath.row == 0 {
                changeIndex(srcPath.row, dest: destPath.row, proxylist: &proxys)
            }else {
                changeIndex(srcPath.row, dest: destPath.row, proxylist: &chainProxys)
            }
        }else {
            if srcPath.section == 0{
                let p = proxys.remove(at: srcPath.row)
                chainProxys.insert(p, at: destPath.row)
            }else {
                let p = chainProxys.remove(at: srcPath.row)
                proxys.insert(p, at: destPath.row)
            }
        }
    }
    public func changeIndex(_ src:Int,dest:Int,proxylist:inout [SFProxy] ){
        let r = proxylist.remove(at: src)
        proxylist.insert(r, at: dest)
        
    }
    func save()  {
        
    }
    static func load(_ path:String)->Proxys?{
        do {
            let string  = try String.init(contentsOfFile: path)
            guard let proxy = Mapper<Proxys>().map(JSONString: string) else {
                return nil
            }
            return proxy
        }catch let e {
            print("\(e.localizedDescription)")
            return nil
        }
        
    }
    public func updateProxy(_ p:SFProxy){
        //todo
        var oldArray:[SFProxy]
        var newArray:[SFProxy]
        if p.chain {
            oldArray = chainProxys
            newArray = proxys
        }else {
            oldArray = proxys
            newArray = chainProxys
        }
        if let firstSuchElement = oldArray.index(where: { $0 == p })
            .map({ oldArray.remove(at: $0) }) {
            
            
            newArray.append(firstSuchElement)
        }
    }
    
    
    public func addProxy(_ proxy:SFProxy) ->Int {
        
        var found = false
        
        var index  = 0
        for idx in 0 ..< proxys.count {
            let p = proxys[idx]
            if p.serverAddress == proxy.serverAddress && p.serverPort == proxy.serverPort {
                found = true
                index = idx
                break
            }
        }
        if found {
            proxys.remove(at: index)
            proxys.insert(proxy, at: index)
        }else {
            proxys.append(proxy)
            
        }
        let selectIndex = proxys.count - 1
        return selectIndex
    }
}
public class SFProxy:CommonModel {
    public var proxyName:String = ""
    public var serverAddress:String = ""
    public var serverPort:String = ""
    public var password:String = ""
    public var method:String = ""
    public var tlsEnable:Bool = false //对于ss ,就是OTA 是否支持
    public var type:SFProxyType = .SS
    public var pingValue:Float = 0
    public var tcpValue:Double = 0
    public var dnsValue:Double = 0
    public var priority:Int = 0
    public var enable:Bool = true
    public var serverIP:String = ""
    public var countryFlag:String = ""
    public var chain:Bool = false
    public var isoCode:String = ""
    public var udpRelay:Bool = false
    
    public var mode:String  = "fast2"
    public var kcptun:Bool = false
    public var key:String = "" //pkdf2 use
    public var cryptoType:String = "none"
    public func countryFlagFunc() ->String{
        if countryFlag.isEmpty {
            return showString()
        }else {
            return countryFlag + " " + proxyName
        }
    }
    public override func mapping(map: Map) {
        
        proxyName  <- map["pName"]
        serverAddress <- map["serverAddress"]
        serverPort <- map["serverPort"]
        
        password <- map["password"]
        method <- map["method"] //http socks5 user
        tlsEnable   <- map["tlsEnable"]
        type   <- (map["type"],EnumTransform<SFProxyType>())
        countryFlag    <- map["countryFlag"]
        priority         <- map["priority"]
        isoCode      <- map["isoCode"]
        serverIP       <- map["serverIP"]
        chain  <- map["chain"]
        udpRelay  <- map["udpRelay"]
        kcptun  <- map["kcptun"]
        mode     <- map["mode"]
        key  <- map["key"]
        tcpValue <- map["tcpValue"]
        priority <- map["priority"]
        //birthday    <- (map["birthday"], DateTransform())
        
        
        
    }
    public static func createProxyWithURL(_ configString:String) ->(proxy:SFProxy?,message:String) {
        // http://base64str
        //"aes-256-cfb:fb4b532cb4180c9037c5b64bb3c09f7e@108.61.126.194:14860"
        //mayflower://xx:xx@108.61.126.194:14860
        //"ss://Y2hhY2hhMjA6NTg0NTIweGMwQDQ1LjMyLjkuMTMwOjE1MDE?remark=%F0%9F%87%AF%F0%9F%87%B5"
        //(lldb) n
        //(lldb) po x
        //"ss://Y2hhY2hhMjA6NTg0NTIweGMwQDQ1LjMyLjkuMTMwOjE1MDE?remark=🇯🇵"
        //let x = configString.removingPercentEncoding!
        //NSLog("%@", configString)
        if let u = NSURL.init(string: configString){
            
            
            guard  let scheme = u.scheme else {
                //找不到scheme 会crash
                //alertMessageAction("\(configString) Invilad", complete: nil)
                return (nil,"\(configString) Invilad")
            }
            
            guard let proxy:SFProxy = SFProxy.create(name: "server", type: .SS, address: "", port: "443", passwd: "", method: "aes-256-cfb", tls: false) else  {
                return (nil, "create proxy error")
            }
            
            let t = scheme.uppercased()
            if t == "HTTP" {
                proxy.type = .HTTP
            }else if t == "HTTPS" {
                proxy.type = .HTTPS
                proxy.tlsEnable = true
            }else if t == "SOCKS5" {
                proxy.type = .SOCKS5
            }else if t == "SS" {
                proxy.type = .SS
            }else if t == "SS3" {
                proxy.type = .SS3
            }else {
                return (nil, "URL \(scheme) Invilad")
                
            }
            let result = u.host!
            
            if let query  = u.query {
                let x = query.components(separatedBy: "&")
                for xy in x {
                    let x2 = xy.components(separatedBy: "=")
                    if x2.count == 2 {
                        if x2.first! == "remark" {
                            proxy.proxyName = x2.last!.removingPercentEncoding!
                        }
                        if x2.first! == "tlsEnable"{
                            let v = Int(x2.last!)
                            if v == 1  {
                                proxy.tlsEnable = true
                            }else {
                                proxy.tlsEnable = false
                            }
                        }
                    }
                }
            }
            var paddedLength = 0
            let left = result.characters.count % 4
            if left != 0 {
                paddedLength = 4 - left
            }
            
            let padStr = result + String.init(repeating: "=", count: paddedLength)
            if let data = Data.init(base64Encoded: padStr, options: .ignoreUnknownCharacters) {
                if let resultString = String.init(data: data , encoding: .utf8) {
                    let items = resultString.components(separatedBy: ":")
                    if items.count == 3 {
                        proxy.method = items[0].lowercased()
                        proxy.serverPort = items[2]
                        
                        if let r = items[1].range(of: "@"){
                            let tempString = items[1]
                            proxy.password = tempString.substring(to: r.lowerBound)
                            proxy.serverAddress = tempString.substring(from: r.upperBound)
                            return (proxy,"OK")
                        } else {
                            return (nil,"\(resultString) Invilad")
                        }
                    }else {
                        return (nil,"\(resultString) Invilad")
                    }
                }else{
                    return (nil,"\(configString) Invilad")
                }
                
                
            }else {
                return (nil,"\(configString) Invilad")
            }
            
            
        }else {
            return (nil,"\(configString) Invilad")
        }
        
    }
    public static func createProxyWithLine(line:String,pname:String) ->SFProxy? {
        
        let name = pname.trimmingCharacters(in:
            NSCharacterSet.whitespacesAndNewlines)
        
        
        
        let list =  line.components(separatedBy: ",")
        
        if list.count >= 5{
            let t = list.first?.uppercased().trimmingCharacters(in:
                NSCharacterSet.whitespacesAndNewlines)
            //占位
            guard let proxy:SFProxy = SFProxy.create(name: name, type: .SS, address: "", port: "443", passwd: "", method: "aes-256-cfb", tls: false) else  {
                return (nil)
            }
            if t == "HTTP" {
                proxy.type = .HTTP
            }else if t == "HTTPS" {
                proxy.type = .HTTPS
                proxy.tlsEnable = true
            }else if t == "SOCKS5" {
                proxy.type = .SOCKS5
            }else if t == "SS" {
                proxy.type = .SS
            }else if t == "SS3" {
                proxy.type = .SS3
            }else {
                //alertMessageAction("\(scheme) Invilad", complete: nil)
                //return
            }
            
            proxy.serverAddress =  list[1].trimmingCharacters(in:
                NSCharacterSet.whitespacesAndNewlines)
            proxy.serverPort =   list[2].trimmingCharacters(in:
                NSCharacterSet.whitespacesAndNewlines)
            proxy.method =   list[3].trimmingCharacters(in:
                NSCharacterSet.whitespacesAndNewlines).lowercased()
            proxy.password =   list[4].trimmingCharacters(in:
                NSCharacterSet.whitespacesAndNewlines)
            
            if  list.count >= 6 {
                let temp = list[5]
                let tt = temp.components(separatedBy: "=")
                if tt.count == 2{
                    if tt.first! == "tls" {
                        if tt.last! == "true"{
                            proxy.tlsEnable = true
                        }
                    }
                }
            }
            return proxy
        }
        return nil
        
        
        
    }
    public static func create(name:String,type:SFProxyType ,address:String,port:String , passwd:String,method:String,tls:Bool) ->SFProxy?{
        
        // Convert JSON String to Model
        //let user = Mapper<User>().map(JSONString: JSONString)
        // Create JSON String from Model
        //let JSONString = Mapper().toJSONString(user, prettyPrint: true)
        guard let proxy = Mapper<SFProxy>().map(JSONString: "{\"type\":0}") else {
            return nil
        }
        
        proxy.proxyName = name
        proxy.serverAddress = address
        proxy.serverPort = port
        proxy.password = passwd
        proxy.method = method
        if type == .HTTPS {
            proxy.tlsEnable = true
        }else {
            proxy.tlsEnable = tls
        }
        
        if method == "aes" {
            proxy.type = .HTTPAES
        }else {
            proxy.type = type
        }
        
        return proxy
    }
    public required init?(map: Map) {
        super.init(map: map)
        //self.mapping(map: map)
    }
    //public required init?(map: Map) {
    //super.init(map: map)
    //super.init(map: map)
    //fatalError("init(map:) has not been implemented")
    //}
    
    
    public  func showString() ->String {
        if !proxyName.isEmpty{
            return proxyName
        }else {
            if !isoCode.isEmpty {
                return  isoCode
            }
        }
        return serverAddress
    }
    
    
    //    public func resp() ->[String:Any]{
    //        return ["name":proxyName as AnyObject,"host":serverAddress as AnyObject,"port":serverPort,"protocol":type.description,"method":method,"passwd":password,"tls":NSNumber.init(value: tlsEnable),"priority":NSNumber.init(value: priority),"enable":NSNumber.init(value: enable),"countryFlag":countryFlag,"isoCode":isoCode,"ipaddress":serverIP,"mode":mode,"kcptun":NSNumber.init(value:kcptun ),"chain":chain]
    //    }
    //open  static func map(_ name:String,value:JSON) ->SFProxy{
  
    
    public func typeDesc() ->String{
        if tlsEnable && type == .HTTP {
            return "Type: " + "HTTPS"
        }
        return "Type: " + type.description
    }
    static open func loadFromDictioanry(_ dic:AnyObject?) ->SFProxy?{
        return self.fromDictionary(dic)
    }
    public func base64String() ->String {
        let tls = tlsEnable ? "1" : "0"
        let c = chain ? "1" : "0"
        let string = method + ":" + password + "@" + serverAddress  + ":" + serverPort
        
        //let string = config.method + ":" + config.password + "@" + a + ":" + p
        
        //let string = "aes-256-cfb:fb4b532cb4180c9037c5b64bb3c09f7e@108.61.126.194:14860"//
        let utf8str = string.data(using: .utf8)
        let base64Encoded = type.description.lowercased()  + "://" + utf8str!.base64EncodedString(options: .endLineWithLineFeed) +   "?tlsEnable=" + tls + "&chain=" + c
        return base64Encoded
    }
    
    deinit{
        
    }
}
public func ==(lhs:SFProxy, rhs:SFProxy) -> Bool { // Implement Equatable
    return lhs.serverAddress == rhs.serverAddress && lhs.serverPort == rhs.serverPort
}
