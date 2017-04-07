//
//  ProxyGroupSettings.swift
//  Surf
//
//  Created by 孔祥波 on 16/4/5.
//  Copyright © 2016年 yarshure. All rights reserved.
//

import Foundation
import SwiftyJSON
import ObjectMapper
import AxLogger
public class ProxyGroupSettings:CommonModel {
    public static let share:ProxyGroupSettings = {
        let url = groupContainerURL().appendingPathComponent(kProxyGroupFile)
        var content:String = "{}"
        do {
            content = try String.init(contentsOf: url, encoding: .utf8)
        }catch let e {
            print("\(e)")
        }
        
        guard let set = Mapper<ProxyGroupSettings>().map(JSONString: content) else {
            fatalError()
        }
        guard let ps = Mapper<Proxys>().map(JSONString: "{}") else {
            fatalError()
        }
        set.proxyMan = ps
        return set
    }()
    //var defaults:NSUserDefaults?// =
    public var editing:Bool = false
    public static let defaultConfig = ".surf"
    public var historyEnable:Bool = false
    var proxyMan:Proxys!
    public var disableWidget:Bool = false
    public var dynamicSelected:Bool = false
    public var proxyChain:Bool = false
    
    public var proxyChainIndex:Int = 0
    public var showCountry:Bool = true
    public var widgetProxyCount:Int = 3
    public var selectIndex:Int = 0
    public var config:String = "surf.conf"
    public var saveDBIng:Bool = false
    public required init?(map: Map) {
        super.init(map: map)
        //self.mapping(map: map)
    }
    public override func mapping(map: Map) {
        editing  <- map["editing"]
        historyEnable <- map["historyEnable"]
        proxyMan <- map["proxyMan"]
        
        
        disableWidget  <- map["disableWidget"]
        dynamicSelected <- map["dynamicSelected"]
        proxyChain <- map["proxyChain"]
        
        
        proxyChainIndex  <- map["proxyChainIndex"]
        showCountry <- map["showCountry"]
        widgetProxyCount <- map["widgetProxyCount"]
        selectIndex <- map["selectIndex"]
        
        config  <- map["config"]
        saveDBIng <- map["saveDBIng"]
       

    }
    
    public var selectedProxy:SFProxy? {
        return proxyMan.selectedProxy( selectIndex)
    }
    public func updateProxyChain(_ isOn:Bool) ->String?{

        proxyChain = isOn
        try! save()
        return nil
        // todo dynamic send tunnel provider
    }
    public var chainProxy:SFProxy?{
        get {
            if proxyChainIndex < proxyMan.chainProxys.count{
                return proxyMan.chainProxys[proxyChainIndex]
            }else {
                return proxyMan.chainProxys.first
            }
            
        }
    }
    public func changeIndex(_ srcPath:IndexPath,destPath:IndexPath){
        //有个status section pass
        proxyMan.changeIndex(srcPath, destPath: destPath)
       
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
        
        return proxyMan.findProxy(proxyName, dynamicSelected: dynamicSelected, selectIndex: selectIndex)
        
        
    }
    public func cutCount() ->Int{
        return proxyMan.cutCount()
    }
    public func removeProxy(_ Index:Int,chain:Bool = false) {
        proxyMan.removeProxy(Index, chain: chain)
        do {
            try save()
        }catch let e as NSError{
            print("proxy group save error \(e)")
        }
    }


    public var proxys:[SFProxy] {
        get {
            var new:[SFProxy] = []
            new.append(contentsOf: proxyMan.proxys)
            new.append(contentsOf: proxyMan.chainProxys)
            return new
        }
    }
   

    
    public func addProxy(_ proxy:SFProxy) -> Bool {
        
        
        selectIndex = proxyMan.addProxy(proxy)
        try! save()
        return true
    }
    
    public func updateProxy(_ p:SFProxy){
        //todo
        proxyMan.updateProxy(p)
    }
    public func save() throws {//save to group dir
        
        if let js = self.toJSONString() {
            let url = groupContainerURL().appendingPathComponent(kProxyGroupFile)
            print("save to \(url)")
            try js.write(to: url, atomically: true, encoding: .utf8)
        }
        
    }
    
    
}
