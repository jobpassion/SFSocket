//
//  RequestHelper.swift
//  Surf
//
//  Created by 孔祥波 on 16/4/28.
//  Copyright © 2016年 yarshure. All rights reserved.
//

import Foundation
//import SQLite
import GRDB
import AxLogger
import Xcon
import XProxy
import XFoundation

public class RequestHelper{
    static public let shared = RequestHelper()
    
    //var db:Connection?
    var requests:[SFRequestInfo] = []
    var dbQueue:DatabaseQueue?
    let fileName = "db.zip"
    public func open(_ path:String,readonly:Bool,session:String){
  
        
        var p:String
        if path.components(separatedBy: "/").count == 1 {
             let url  = groupContainerURL().appendingPathComponent("Log/" + session + "/"  )
            p = url.path
        }else {
            p = path
        }
        do {
            
            _ = try FileManager.checkAndCreate(pathDir:p )
            p += "/" + fileName
            dbQueue = try DatabaseQueue(path: p)
            if let db = dbQueue {
                initGRDB(db)
            }
            
            //initDatabase(db!)
        }catch let e as NSError{
            SKit.log("open log  db error \(p) \(e.description)",level: .Error)
        }
        
        
        
    }
    func initGRDB(_ db:DatabaseQueue){
        do {
            try db.inDatabase { db in
                try db.execute(
                    "CREATE TABLE \"requests\" (\"id\" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,\"reqID\" INTEGER NOT NULL,\"subID\" INTEGER NOT NULL , \"mode\" TEXT NOT NULL, \"url\" TEXT NOT NULL, \"app\" TEXT NOT NULL, \"start\" REAL NOT NULL, \"status\" TEXT NOT NULL, \"closereason\" INTEGER NOT NULL, \"reqHeader\" TEXT NOT NULL, \"respHeader\" TEXT NOT NULL, \"proxyName\" TEXT NOT NULL, \"name\" TEXT NOT NULL, \"type\" INTEGER NOT NULL, \"ruleTime\" REAL NOT NULL, \"Est\" REAL NOT NULL, \"transferTiming\" REAL NOT NULL, \"tx\" INTEGER NOT NULL, \"rx\" INTEGER NOT NULL, \"end\" REAL NOT NULL, \"interface\" INTEGER NOT NULL, \"localIP\" TEXT NOT NULL, \"remoteIP\" TEXT NOT NULL, \"wakeup\" REAL NOT NULL, \"sleep\" REAL NOT NULL);")
                
            }
            
            
        }catch let e as NSError{
            SKit.log("create table error:",items: e.localizedDescription,level: .Error)
        }
        
       
    }
    func saveReqInfo(_ infoReq:SFRequestInfo){
        if infoReq.url.isEmpty {
            SKit.log("\(infoReq.reqID) don't have url and don't save record",level: .Error)
            return
        }
        requests.append(infoReq)
        self.writeReqInfoToDB()
    }
    func writeReqInfoToDB()  {
        if requests.count == 0 {
            return
        }
        guard let info = self.requests.first else {return}
        
        let address = info.localIPaddress as NSString
        if address.contains("/") {
            SKit.log("\(info.localIPaddress) error",level: .Error)
            return
        }
        //debugLog("\(info.url)   \(info.traffice.rx):\(info.traffice.tx)")
       
        if let d = dbQueue {
            do  {
                //requests.append(info)
                var req = ""
                var resp = ""
                if info.mode != .TCP {
                    if let reqh = info.reqHeader {
                        req =  reqh.headerString(nil)
                    }
                    if let resph = info.respHeader {
                        resp = resph.headerString(nil)
                    }
                    
                }
                try d.inDatabase { db in
                    //id|reqID|subID|mode|url|app|start|status|closereason|reqHeader|respHeader|proxyName|name|type|ruleTime|Est|transferTiming|tx|rx|end|interface|localIP|remoteIP
                     //reqID,subID,?,?,info.reqID,info.subID
                    try db.execute(
                       //有bug
                        "INSERT INTO requests (reqID,subID,mode, url, app,start,status,closereason,reqHeader,respHeader,proxyName,name,type,ruleTime,Est,transferTiming, tx,rx,end,interface,localIP,remoteIP,wakeup,sleep) VALUES (?,?,?, ?, ?,?,?, ?, ?,?,?, ?, ?,?,?, ?, ?,?,?,?,?,?,?,?) ",arguments: [Int64(info.reqID),Int64(info.subID), info.mode.description, info.url,info.app,info.sTime.timeIntervalSince1970,info.status.description,info.closereason.rawValue,req,resp,info.rule.proxyName,info.rule.name,Int64(info.rule.type.rawValue),info.rule.timming,info.connectionTiming,info.transferTiming,Int64(info.traffice.tx),Int64(info.traffice.rx),info.eTime.timeIntervalSince1970,info.interfaceCell,info.localIPaddress,info.remoteIPaddress,SKit.lastSleepTime.timeIntervalSince1970,SKit.lastSleepTime.timeIntervalSince1970])

                    
                    }
               
            } catch let e  as NSError {
                SKit.log("insert error ",items: e.description,level:.Error)
            }
            
        }else {
            
            SKit.log("insert error no db ",level:.Error)
        }
        self.requests.removeFirst()
        
    }
    public func openForApp(_ session:String) ->URL?{
        
        let p = groupContainerURL().appendingPathComponent("Log/" + session + "/")
        open(p.path,readonly: true,session: session)
       
        return p
        
    }
    public func  query(_ mode:String = "",host:String = "",agent:String = "") -> [SFRequestInfo] {
        let  result = fetchAll()
        let new = result.filter { req -> Bool in
            if req.url.isEmpty {
                return false
            }
            if mode == req.mode.rawValue {
                return true
            }
            if let _ = req.host.range(of: host) {
                return true
            }
            
            if let header = req.reqHeader,let _ = header.app.range(of: agent) {
                return true
            }
            
            
            return false
        }

        return new
    }
    
    public func  fetchAll() -> [SFRequestInfo] {
        var result:[SFRequestInfo] = []
        
        

        var dbx:DatabaseQueue!
        if let db = dbQueue {
            dbx = db
        }else {
            return result
        }
        do {
            //requests.order([start.asc])
            //id|mode|url|app|start|state|closereason|reqHeader|respHeader|proxyName|name|type|ruleTime|Est|transferTiming|tx|rx|end|interface|localIP|remoteIP
            try dbx.inDatabase { db in
                let rows = try! Row.fetchCursor(db, "SELECT * FROM requests order by id desc")
                while let row = try rows.next() {
                    let req = SFRequestInfo.init(rID:0 , sID: 0)
                    //MARK: -fixme

                    req.reqID = row["reqID"]
                    req.subID = row["subID"]
                    
                    req.mode =  SFConnectionMode(rawValue:row["mode"])!
                    req.status = SFConnectionStatus(rawValue:row["status"])!
                    req.closereason = SFConnectionCompleteReason(rawValue:row["closereason"])!
                    req.url = row["url"]
                    if req.url.isEmpty {
                        continue
                    }
                    req.app = row["app"]
                    req.sTime = Date.init(timeIntervalSince1970: row["start"])
                    result.append(req)
                    
                    
                    if req.mode != .TCP {
                        var head:String = row["respheader"]
                        if let d = head.data(using: .utf8) {
                            if d.count > 0 {
                                req.respHeader = SFHTTPResponseHeader.init(data: d)
                            }
                            
                            
                        }
                        head = row["reqheader"]
                        if let d = head.data(using: .utf8) {
                            if d.count > 0 {
                                req.reqHeader =  SFHTTPRequestHeader.init(data: d)
                            }
                            
                        }
                        
                    }
                    req.rule.timming = row["ruleTime"]
                    req.rule.proxyName = row["proxyName"]
                    req.rule.name = row["name"]
                    //MARK --fixme
                    //req.rule.type = SFRulerType(rawValue: row["type"])!
                    req.connectionTiming = row["Est"]
                    req.transferTiming = row["transferTiming"]
                    let rx:Int = row["rx"]
                    let tx:Int = row["tx"]
                    
                    req.traffice.rx = UInt(rx)
                    req.traffice.tx = UInt(tx)

                    
                    req.eTime = Date.init(timeIntervalSince1970: row["end"])
                    req.interfaceCell = row["interface"]
                    req.localIPaddress = row["localIP"]
                    req.remoteIPaddress = row["remoteIP"]
                    
                    
                }
                
            }
        }catch let e {
            print(e.localizedDescription)
        }
        
        return result
    }
    
    
}
