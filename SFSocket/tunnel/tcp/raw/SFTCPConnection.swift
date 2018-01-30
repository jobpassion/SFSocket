//
//  SFTCPConnection.swift
//  Surf
//
//  Created by yarshure on 15/12/25.
//  Copyright © 2015年 yarshure. All rights reserved.
//

import Foundation
import lwip
import AxLogger
import Xcon
import XRuler
class SFTCPConnection: SFConnection {

    var reqHeader:SFHTTPHeader?
    var respHeader:SFHTTPHeader?
    var domainName:String = ""
    //var headerData:NSMutableData = NSMutableData()
    override internal init(tcp:SFPcb, host:UInt32,port:UInt16, m:SFTCPConnectionManager){
        super.init(tcp: tcp,host: host,port: port,m: m)
        //self.sID = SFHTTPConnectionID++
        self.reqInfo.mode = .TCP
        let remote = info.remote
        let ip = remote.ipString()
        if let domain = SFSettingModule.setting.searchIPAddress(ip){
            
            let d = domain.delLastN(1)
            SKit.log("\(cIDString) TCP " + ip  + " Find domain " +  d,level: .Trace)
            domainName = d
        }
        
        if !domainName.isEmpty{
            reqInfo.url = domainName + ":\(info.remote.port)"
        }else {
            reqInfo.url = ip + ":\(info.remote.port)"
        }
        reqInfo.lport = info.tun.port
        self.reqInfo.remoteIPaddress = ip
        SKit.log("\(cIDString) remote:\(reqInfo.remoteIPaddress):\(remote.port) init",level: .Warning)
      
    }
    
    override func configLwip() {
        config_tcppcb(pcb, Unmanaged.passUnretained(self).toOpaque())
        configConnection()
        reqInfo.sTime = Date()
        
    }
    override func configConnection(){
        SKit.log("\(cIDString) \(reqInfo.url) configConnection" ,level: .Trace)
        
        var dest = reqInfo.remoteIPaddress
        
        if !domainName.isEmpty{
            dest = domainName
            
        }
        
        
        
        if genPolicy(dest,useragent: "") {
            //setUpConnector()
            if reqInfo.rule.policy == .Reject {
                byebyeRequest()
            }else {
                 SKit.log("\(cIDString) shoud start",level: .Trace)
            }
           
        }else {
            
            SKit.log(":\(cIDString)\(reqInfo.url) should not waiting? ",level: .Warning)
        }
        
        
    }
    override func setUpConnector(){
        var  host = reqInfo.remoteIPaddress
        
        let port = info.remote.port
        
       SKit.log("\(cIDString)  \(host):\(port) \(reqInfo.rule.policy) \(String(describing: reqInfo.proxy?.type))",level: .Debug)
       
        if reqInfo.rule.policy == .Reject {
            byebyeRequest()
            return
        }else {
            if reqInfo.rule.policy == .Direct {
                
                reqInfo.remoteIPaddress = info.remote.ipString()
                setUpConnector(reqInfo.remoteIPaddress, port: port)
            }else  {
                //findProxy()
                // 防止IP 失效，或者被污染
                if !domainName.isEmpty {
                    host = domainName
                }
                setUpConnector(host, port: port)
                
            }
            
        }
        let message = String.init(format:"#### TCP:%@", reqInfo.url)
        
        SKit.log(message,level: .Trace)
        connection(30)
        
        
    }

    override func incomingData(_ d:Data, len:Int){
        #if LOGGER
        reqInfo.sendData.appendData(d)
        #endif
        reqInfo.activeTime = Date()
      
        if reqInfo.rule.policy == .Reject{
           SKit.log("\(cIDString)  drop data  request ip: \(info.remote.ipString()) port: \(info.remote.port)",level: .Debug)
            reqInfo.status = .Complete
            reqInfo.closereason = .clientReject
            return
        } else {
            SKit.log("\(cIDString)  incomingData  \(reqInfo.url) \(d.count)",level:  .Trace)
            bufArray.append(d)
        }
        
        client_send_to_socks()
    }
    override func client_send_to_socks(){
        let st = (reqInfo.status == .Established) || (reqInfo.status == .Transferring)
        if !st {
            return
        }
        super.client_send_to_socks()
        
    }
    override func client_socks_recv_initiate(){
        
//        assert(!reqInfo.client_closed)
//        assert(!reqInfo.socks_closed)
//        assert(reqInfo.socks_up)
        guard let c = connector else {
            AxLogger.log("connector disconnected client_socks_recv_initiate", level: .Trace)
            return
        }
        
        
        if reqInfo.status !=  .RecvWaiting {
            //多次读event 
             SKit.log("\(cIDString) readData tag:\(rTag)",level: .Debug)
            c.readDataWithTag(rTag)
        }else {
            SKit.log("\(cIDString)  recv waiting length:\(socks_recv_bufArray.count)",level:.Trace)
            // debugLog("\(cIDString) recv waiting")
        }
        
        
    }
    

    override func checkStatus() {
        //SKit.log("\(cIDString) header queue:\(reqHeaderQueue.count) index:\(requestIndex) ",level: .Debug)
        
        if socks_recv_bufArray.count == 0 && bufArray.count == 0{
            if reqInfo.idleTimeing > 60.0 * 10{
                SKit.log("\(cIDString) \(reqInfo.host) checkStatus timeout",level: .Warning)
                client_free_socks()
                
            }
        }else {
            if reqInfo.idleTimeing > 60.0 * 5{
                SKit.log("\(cIDString) \(reqInfo.host)   will close recv:\(socks_recv_bufArray.count) send: \(bufArray.count)",level: .Warning)
                client_free_socks()
            }
            
        }

    }

}
