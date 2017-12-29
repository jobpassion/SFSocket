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

public class RequestHelper{
    static public let shared = RequestHelper()
    
    //var db:Connection?
    var requests:[SFRequestInfo] = []
    var dbQueue:DatabaseQueue?
    public func open(_ path:String,readonly:Bool,stamp:TimeInterval){
    //need memory 493kb
//        if let d = db {
//            //db.
//        }
        
        var p:String
        if path.components(separatedBy: "/").count == 1 {
             let url  = groupContainerURL().appendingPathComponent("Log/" + path + "/db.zip")
            p = url.path
        }else {
            p = path + "/db.zip"
        }
        
        //let url = groupContainerURL().appendingPathComponent(fn)
        //let p = url.path
            do {
                //db = try Connection(p,readonly: readonly)
               
                
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
        let bId = Bundle.main.infoDictionary!["CFBundleIdentifier"] as! String
        if bId == "com.yarshure.Surf" ||  bId == "com.yarshure.SurfToday"{
            print("don't need init")
        }else {
            do {
                try db.inDatabase { db in
                    try db.execute(
                        "CREATE TABLE \"requests\" (\"id\" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,\"reqID\" INTEGER NOT NULL,\"subID\" INTEGER NOT NULL , \"mode\" TEXT NOT NULL, \"url\" TEXT NOT NULL, \"app\" TEXT NOT NULL, \"start\" REAL NOT NULL, \"status\" TEXT NOT NULL, \"closereason\" INTEGER NOT NULL, \"reqHeader\" TEXT NOT NULL, \"respHeader\" TEXT NOT NULL, \"proxyName\" TEXT NOT NULL, \"name\" TEXT NOT NULL, \"type\" INTEGER NOT NULL, \"ruleTime\" REAL NOT NULL, \"Est\" REAL NOT NULL, \"transferTiming\" REAL NOT NULL, \"tx\" INTEGER NOT NULL, \"rx\" INTEGER NOT NULL, \"end\" REAL NOT NULL, \"interface\" INTEGER NOT NULL, \"localIP\" TEXT NOT NULL, \"remoteIP\" TEXT NOT NULL, \"wakeup\" REAL NOT NULL, \"sleep\" REAL NOT NULL);")
//                    try db.create(table:"requests") { t in
//                        
//                        t.column("id", .Integer).primaryKey()
//                        t.column("reqID", .Integer)
//                        t.column("subID", .Integer)
//                        t.column("mode", .TEXT).notNull()
//                        t.column("url", .TEXT).notNull()
//                        t.column("app", .TEXT).notNull()
//
//
//                        t.column("start", .Double).notNull()
//                        t.column("status", .TEXT).notNull()
//                        t.column("closereason", .Integer).notNull()
//                        t.column("reqHeader", .TEXT).notNull()
//                        t.column("respHeader", .TEXT).notNull()
//                        t.column("proxyName", .TEXT).notNull()
//                        t.column("name", .TEXT).notNull()
//                        t.column("type", .Integer).notNull()
//                        t.column("ruleTime", .Double).notNull()
//                        t.column("Est", .Double).notNull()
//                        t.column("transferTiming", .Double).notNull()
//                        t.column("tx", .Integer).notNull()
//                        t.column("rx", .Integer).notNull()
//                        t.column("end", .Double).notNull()
//                        t.column("interface", .Integer).notNull()
//                        t.column("localIP", .TEXT).notNull()
//                        t.column("remoteIP", .TEXT).notNull()
//
//                       
//                    }
                    
                }
                
                
            }catch let e as NSError{
                SKit.log("create table error:",items: e.localizedDescription,level: .Error)
            }
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
        open(p.path,readonly: true,stamp: 0)
       
        return p
        
    }
    public func  query() -> [SFRequestInfo] {
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
//                    req.dbID =  UInt32(row.value(named: "id"))
//                    
////                    req.dbID =  row.value(named: "id")
//                    req.reqID = UInt32(row.value(named: "reqID"))
//                    req.subID =  UInt32(row.value(named: "subID"))
                    //print(row[url])
                    //print(row[url])
                    req.mode =  SFConnectionMode(rawValue:row["mode"])!
                    req.url = row["url"]
                    req.app = row["app"]
                    req.sTime = Date.init(timeIntervalSince1970: row["start"])
                    result.append(req)
                    req.status = SFConnectionStatus(rawValue:row["status"])!
                    req.closereason = SFConnectionCompleteReason(rawValue:row["closereason"])!
                    
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
    func test(){
        
//        let url = applicationDocumentsDirectory.appendingPathComponent("test.sqlite")
//        let db = try! Connection(url.path!)
//        
//        db.trace { print($0) }
//        
//        let users = Table("users")
//        
//        let id = Expression<Int64>("id")
//        let email = Expression<String>("email")
//        let name = Expression<String?>("name")
//        
//        try! db.run(users.create { t in
//            t.column(id, primaryKey: true)
//            t.column(email, unique: true, check: email.like("%@%"))
//            t.column(name)
//            })
//        
//        let rowid = try! db.run(users.insert(email <- "alice@mac.com"))
//        let alice = users.filter(id == rowid)
//        
//        for user in try! db.prepare(users) {
//            print("id: \(user[id]), email: \(user[email])")
//        }
//        
//        let emails = VirtualTable("emails")
//        
//        let subject = Expression<String?>("subject")
//        let body = Expression<String?>("body")
//        
//        try! db.run(emails.create(.FTS4(subject, body)))
//        
//        try! db.run(emails.insert(
//            subject <- "Hello, world!",
//            body <- "This is a hello world message."
//            ))
//        
//        let row = db.pluck(emails.match("hello"))
//        
//        let query = try! db.prepare(emails.match("hello"))
//        for row in query {
//            print(row[subject])
//        }
    }
    
}
