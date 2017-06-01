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

class SFTCPConnection: SFConnection {
//    override internal init(tcp:SFPcb, host:UInt32,port:UInt16, m:SFTCPConnectionManager){
//        pcb = tcp
//        sID = SFConnectionID++
//        
//        local_addr = IPAddr(i: 0,p: 0)
//        remote_addr = IPAddr(i: 0, p: 0)
//        pcbinfo(pcb,&local_addr.ip,&remote_addr.ip,&local_addr.port,&remote_addr.port)
//        manager = m
//        connector = DirectConnector.connectorWithSelectorPolicy("", targetHostname: local_addr.ipString(), targetPort: local_addr.port)
//        super.init()
//    }
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
        config_tcppcb(pcb, self)
        configConnection()
        reqInfo.sTime = Date() as Date
        //change to use db
        //SFTCPConnectionManager.manager.addReqInfo(self.reqInfo)
       //SKit.log("\(cIDString) ",level:.Debug)
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
            SKit.log("\(cIDString)  incomingData  \(reqInfo.url) \(d.count)",level:  .Debug)
            bufArray.append(d)
        }
        
        processData("\(cIDString)  incomingData")
    }
    func processData(_ reason:String) {
        client_send_to_socks()
    }
    override func client_socks_recv_initiate(){
        
        assert(!reqInfo.client_closed)
        assert(!reqInfo.socks_closed)
        assert(reqInfo.socks_up)
        guard let c = connector else {return}
        
        
        if reqInfo.status !=  .RecvWaiting {
             SKit.log("\(cIDString) readData tag:\(rTag)",level: .Debug)
            c.readDataWithTag(rTag)
        }else {
            SKit.log("\(cIDString)  recv waiting length:\(socks_recv_bufArray.length)",level:.Trace)
            // debugLog("\(cIDString) recv waiting")
        }
        
        
    }
    override func client_send_to_socks(){
        let st = (reqInfo.status == .Established) || (reqInfo.status == .Transferring)
        if st  {
            if bufArray.count > 0{
                SKit.log("\(cIDString) now sending data buffer count:\(bufArray.count)",level: .Debug)
                super.client_send_to_socks()
                
            }else {
                //if rTag == 0 {
                    client_socks_recv_initiate()
                //}
                
            }
        }
    }
    override func didWriteData(_ data: Data?, withTag: Int, from: TCPSession){
       SKit.log("\(cIDString) didWriteDataWithTag \(withTag) \(tag)",level: .Debug)
        
        reqInfo.status = .Transferring
        let x = Int64(withTag)
        if let len = bufArrayInfo[x] {
           // tcp_recved(pcb, UInt16(len))
            reqInfo.updateSendTraffic(len)
            bufArrayInfo.removeValue(forKey: x)
            client_socks_send_handler_done(len)
        }
        
        //reqInfo.activeTime = NSDate()
        
           // let d = bufArray.removeFirst()
            
            //let len = bufArrayInfo[tag]
        
        
        
           //SKit.log("\(cIDString) tag:\(tag) time:\(reqInfo.transferTiming) packet sended and delete flow:\(reqInfo.traffice.tx):\(reqInfo.traffice.rx)",level: .Debug)
            // 这个地方有问题 https over http ,how to send this?
        
        
        tag += 1
        
        processData("didWriteData")
    }

    override func  didReadData(_ data: Data, withTag: Int, from: TCPSession){
        
        reqInfo.status = .Transferring
        SKit.log("\(cIDString) didReadData \(reqInfo.url):\(data.length)",level:  .Debug)
        //reqInfo.updateSpeed(UInt(data.length),stat: true)
        reqInfo.updaterecvTraffic(data.count)
        
       //SKit.log("\(cIDString) time:\(reqInfo.transferTiming) tag:\(tag):\(rTag) receive Data length  \(data.length) flow:\(reqInfo.traffice.tx):\(reqInfo.traffice.rx) ",level: .Trace)
//        critLock.lockBeforeDate( NSDate( timeIntervalSinceNow: 0.05))
        rTag += 1
        //critLock.unlock()
//        if reqInfo.rule.policy == .Direct {
//           //SKit.log("\(cIDString) Direct don't need process recv data ",level: .Warning)
//        }else {
//            guard let proxy = reqInfo.proxy else {return}
//
//        }
//        if socks_recv_bufArray.count == 0  {
//            socks_recv_bufArray = data
//        }else {
//            //leaks
//            socks_recv_bufArray.append(data)
//        }
        data.enumerateBytes { (ptr:UnsafeBufferPointer<UInt8>,index: Data.Index, flag:inout Bool) in
            socks_recv_bufArray.append(ptr)
        }
        
        #if LOGGER
        reqInfo.recvData.appendData(data)
        #endif
        client_socks_recv_handler_done(data.count)
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
                SKit.log("\(cIDString) \(reqInfo.host)   will close recv:\(socks_recv_bufArray.length) send: \(bufArray.count)",level: .Warning)
                client_free_socks()
            }
            
        }
        
        
        
        
        //super.checkStatus()
    }
    override func memoryWarning(_ level:DispatchSource.MemoryPressureEvent) {
        if reqInfo.waitingRule {
            if reqInfo.ruleTiming > 1 {
                SKit.log("\(reqInfo.host) memoryWarning Wait Rule \(reqInfo.ruleTiming)",level: .Warning)
            }
        }else {
            let close = reqInfo.shouldClose()
            if close {
                    SKit.log("\(reqInfo.host) memoryWarning \(reqInfo.idleTimeing) will close recv:\(socks_recv_bufArray) && send:\(bufArray.count)",level: .Warning)
                    client_free_socks()
                
            }else {
                SKit.log("\(reqInfo.host) memoryWarning  \(reqInfo.ruleTiming) :recv:\(socks_recv_bufArray) && send:\(bufArray.count)",level: .Warning)
                //client_dealloc()
                SKit.log("\(cIDString) \(reqInfo.host)   will close recv:\(socks_recv_bufArray.length) send: \(bufArray.count)",level: .Warning)
                client_free_socks()
            }
        }
        
    }

}
