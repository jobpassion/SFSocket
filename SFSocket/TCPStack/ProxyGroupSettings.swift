//
//  ProxyGroupSettings.swift
//  Surf
//
//  Created by 孔祥波 on 16/4/5.
//  Copyright © 2016年 yarshure. All rights reserved.
//

import Foundation
import SwiftyJSON

import AxLogger
public class ProxyGroupSettings {
    public static let share:ProxyGroupSettings = {
        return ProxyGroupSettings()
    }()
    //var defaults:NSUserDefaults?// =
    public var editing:Bool = false
    public static let defaultConfig = ".surf"
    public var historyEnable:Bool = false
    
    public var disableWidget:Bool = false
    public var dynamicSelected:Bool = false
    public var proxyChain:Bool = false
    public var chainProxy:SFProxy?{
        get {
            if proxyChainIndex < chainProxys.count{
                return chainProxys[proxyChainIndex]
            }else {
                return nil
            }
            
        }
    }
    public var proxys:[SFProxy] = []
    public var chainProxys:[SFProxy] = []
    public var proxyChainIndex:Int = 0
    public var showCountry:Bool = true
    public var widgetProxyCount:Int = 3
    public var selectIndex:Int = 0
    public var config:String = "surf.conf"
    public var saveDBIng:Bool = false
    public var selectedProxy:SFProxy? {
        if proxys.count > 0 {
            if selectIndex >= proxys.count {
                return proxys.first!
            }
            return proxys[selectIndex]
        }
        return nil
    }
    public func updateProxyChain(_ isOn:Bool) ->String?{
//        var idx:Int = 0
//        if isOn {
//            var found  = false
//            
//            for p in ProxyGroupSettings.share.proxys {
//                if p.proxyName == "DIRECT" {
//                    found = true
//                    break
//                }
//                idx += 1
//                
//            }
//            if !found {
//                return "Please Add DIRECT Proxy"
//            }
//        }
//        
//        ProxyGroupSettings.share.proxyChainIndex = idx
        ProxyGroupSettings.share.proxyChain = isOn
        try! ProxyGroupSettings.share.save()
        return nil
        // todo dynamic send tunnel provider
    }
    public func changeIndex(_ srcPath:IndexPath,destPath:IndexPath){
        //有个status section pass
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
        try! save()
    }
    public func changeIndex(_ src:Int,dest:Int,proxylist:inout [SFProxy] ){
        let r = proxylist.remove(at: src)
        proxylist.insert(r, at: dest)
        
    }
    public func iCloudSyncEnabled() ->Bool{
        return UserDefaults.standard.bool(forKey: "icloudsync");
    }
    public func saveiCloudSync(_ t:Bool) {
        UserDefaults.standard.set(t, forKey:"icloudsync" )
    }
    public func writeCountry(_ config:String,county:String){
        guard let defaults = UserDefaults(suiteName:SKit.groupIdentifier) else {return }
        defaults.set(county , forKey: config)
        defaults.synchronize()
    }
    public func readCountry(_ config:String) ->String?{
        guard let defaults = UserDefaults(suiteName:SKit.groupIdentifier) else {return nil}
        
        return defaults.object(forKey: config)  as? String
    }
    
    public func findProxy(_ proxyName:String) ->SFProxy? {
        
        
        
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
            //let index = 0//self.selectIndex
//             let bId = Bundle.main.infoDictionary!["CFBundleIdentifier"] as! String
//            if bId == "com.yarshure.Surf" {
//            }else {
//                
//            }
        
            
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
        
        do {
            try save()
        }catch let e as NSError{
            print("proxy group save error \(e)")
        }
    }
    public init () {
       loadProxyFromFile()
    }
    public func loadProxyFromConf() {
         let url = groupContainerURL().appendingPathComponent(configMacFn)
        if fm.fileExists(atPath: url.path) {
            
            var  content = ""
            do {
                content = try String.init(contentsOf: url, encoding: .utf8)

            }catch let error {
                AxLogger.log("read config failure \(error.localizedDescription)", level: .Error)
                return
            }
            let x = content.components(separatedBy: "=")
            var proxyFound:Bool = false
            editing = true
            for line in x {
                if line.hasPrefix("[Proxy]"){
                    proxyFound  = true
                    continue
                }
                if proxyFound {
                    let x = line.components(separatedBy: "=")
                    if x.count == 2 {
                        //found record
                        if let p = SFProxy.createProxyWithLine(line: x.last!, pname: x.first!){
                            proxys.append(p)
                        }
                    }else {
                        proxyFound = false
                    }
                }
            }
            editing = false
        }
        
    }
    public func loadProxyFromFile() {
        
        proxys.removeAll()
        chainProxys.removeAll()
//        if bId == MacTunnelIden{
//            loadProxyFromConf()
//            return
//        }
        let url = groupContainerURL().appendingPathComponent(kProxyGroupFile)
        if fm.fileExists(atPath: url.path) {
            do {
                let data = try Data.init(contentsOf: url)
                let jsonOjbect = JSON.init(data: data )
                if jsonOjbect.error == nil {
                    readProxy(jsonOjbect)
                    if jsonOjbect["selectIndex"].error == nil {
                        selectIndex = jsonOjbect["selectIndex"].intValue
                    }
                    if jsonOjbect["config"].error == nil {
                        config = jsonOjbect["config"].stringValue
                    }
                    if jsonOjbect["historyEnable"].error == nil {
                        historyEnable = jsonOjbect["historyEnable"].boolValue
                    }
                    if jsonOjbect["proxyChainEnable"].error == nil {
                        proxyChain = jsonOjbect["proxyChainEnable"].boolValue
                    }
                    if jsonOjbect["disableWidget"].error == nil {
                        disableWidget = jsonOjbect["disableWidget"].boolValue
                    }
                    if jsonOjbect["widgetProxyCount"].error == nil {
                        widgetProxyCount = jsonOjbect["widgetProxyCount"].intValue
                    }
                    if jsonOjbect["proxyChainIndex"].error == nil {
                        proxyChainIndex = jsonOjbect["proxyChainIndex"].intValue
                    }
                    if jsonOjbect["showCountry"].error == nil {
                        showCountry = jsonOjbect["showCountry"].boolValue
                    }else {
                        //showCountry = true
                    }
                }

            }catch let e {
                print(e.localizedDescription)
            }
            
        }
    }
    
    public func readProxy(_ config:JSON) {
//MARK: fixme
//        let p =  config["Proxys"]
//        
//        for (name,value) in p {
//            let proxy = SFProxy.map(name, value: value)
//            proxys.append(proxy)
//
//            
//        }
//        
//        let cp = config["chainProxys"]
//        for (name,value) in cp {
//            let proxy = SFProxy.map(name, value: value)
//            chainProxys.append(proxy)
//            
//            
//        }
        
    }
    
    
    public func addProxy(_ proxy:SFProxy) -> Bool {
        
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
        selectIndex = proxys.count - 1
        try! save()
        return true
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
    public func save() throws {//save to group dir
        var result:[AnyObject] = []
        for p in proxys{
            let o = p.resp()
            //print(o)
            result.append(o as AnyObject)

        }
        
        var resultChain:[AnyObject] = []
        for p in chainProxys {
            let o = p.resp()
            //print(o)
            resultChain.append(o as AnyObject)
            
        }
        var  x:[String:AnyObject] = [:]
        x["Proxys"] = result as AnyObject?
        x["chainProxys"] = resultChain as AnyObject?
        x["selectIndex"] = NSNumber.init(value: selectIndex)
        x["widgetProxyCount"] = NSNumber.init(value: widgetProxyCount)
        x["config"] = config as AnyObject?
        x["historyEnable"] = NSNumber.init(value:  historyEnable)
        x["showCountry"] = NSNumber.init(value:  showCountry)
        x["proxyChainEnable"] = NSNumber.init(value:  proxyChain)
        x["proxyChainIndex"] = NSNumber.init(value:  proxyChainIndex)
        if widgetProxyCount > 0  {
            x["disableWidget"] = NSNumber.init(value:  true)
        }else {
             x["disableWidget"] = NSNumber.init(value:  false)
        }
        
        let j = JSON(x)
        var data:Data
        do {
            try data = j.rawData()
        }catch let error as NSError {
            //AxLogger.log("ruleResultData error \(error.localizedDescription)")
            //let x = error.localizedDescription
            //data = error.localizedDescription.dataUsingEncoding(NSUTF8StringEncoding)!// NSData()
            throw error
        }
         let url = groupContainerURL().appendingPathComponent(kProxyGroupFile)
        do {
            try data.write(to:url, options: .atomic)
        } catch let error as NSError{
            throw error
        }
        

         let p = applicationDocumentsDirectory.appendingPathComponent(config)
    
         let u = groupContainerURL().appendingPathComponent("surf.conf")
        do {
            if fm.fileExists(atPath: u.path) {
                try fm.removeItem(atPath: u.path)
            }
            if fm.fileExists(atPath: p.path) {
                try fm.copyItem(atPath: p.path, toPath: u.path)
            }
            
        }catch let e as NSError {
            print("copy config file error \(e)")
        }
        
    }
    public func importFromFile(){
        
    }
    public func exportToFile(){
        
    }
    
}
