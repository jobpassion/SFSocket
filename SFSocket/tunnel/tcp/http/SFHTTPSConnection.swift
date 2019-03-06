//
//  SFHTTPSConnection.swift
//  Surf
//
//  Created by yarshure on 16/3/7.
//  Copyright © 2016年 yarshure. All rights reserved.
//

import Foundation
import lwip
import AxLogger
import Xcon
import XProxy
class SFHTTPSConnection: SFHTTPRequest {
    override func configLwip() {
        //reqInfo.mode = .HTTPS
        //incomingData(NSData(),len: 0) //init status
        httpStat = .httpReqHeader
        //reqInfo.mode = .HTTPS
        config_tcppcb(pcb, Unmanaged.passUnretained(self).toOpaque())
        reqInfo.sTime = Date() as Date
        //change to db 
        //SFTCPConnectionManager.manager.addReqInfo(self.reqInfo)
    }
    
    override func incomingData(_ d:Data,len:Int){
        
       //SKit.log("\(cIDString) incoming data len \(len)",level: .Debug)
        if d.count > 0 {
            
            #if LOGGER
                reqInfo.sendData.appendData(d)
            #endif
        }
        reqInfo.activeTime =  Date()
        if  reqInfo.mode == .HTTPS  {
            bufArray.append(d)
            //httpStat = .HttpReqSending
        }else{
            switch httpStat {
            case .httpDefault:
                httpStat = .httpReqHeader
               //SKit.log("\(cIDString) connection init",level: .Debug)
                return
            case .httpReqHeader:
                let r = d.range(of: hData, options: Data.SearchOptions.init(rawValue: 0), in: 0 ..< len)
                if let r = r {
                    // body found
                    headerData.append( d.subdata(in: 0 ..< r.lowerBound))
                    reqInfo.reqHeader = SFHTTPRequestHeader(data: headerData)
                    
                    if let reqHeader = reqInfo.reqHeader {
                        if reqHeader.method == .CONNECT {
                            //reqInfo.mode = .CONNECT
                            httpStat = .httpCONNECTSending
                        }
                        
                        
                        reqInfo.url = reqHeader.Url
                        if let app = reqHeader.params["User-Agent"]{
                            reqInfo.app = app
                        }
                        
                        //print( "############ \(reqInfo.url) \(reqInfo.app)",errStream)
                        
                       //SKit.log("\(cIDString) req \(reqHeader.Method) \(reqHeader.Url)\n)",level: .Debug)
                        
                        
                        //why don't add to bufArray, header need fix url, ss socks and other proxy don't need send CONNECT
                        //                        guard let contenLength = reqHeader.params["Content-Length"] else {
                        //                            httpStat = .HttpReqSending
                        //                            processData("http header no body")
                        //                            return
                        //                        }
                        if r.lowerBound + 4 < len {
                            let d = d.subdata(in: r.lowerBound+4 ..< len)
                            bufArray.append(d)
                            //need test
                           //SKit.log("\(cIDString) reqbody:\(bufArray)",level: .Debug)
                        }else{
                           //SKit.log("\(cIDString) no data left for http request body",level: .Debug)
                        }
                        
                    }else {
                       //SKit.log("\(cIDString) parser http header failure",level: .Error)
                    }
                    
                }else {
                    headerData.append(d )
                    return
                }
                break
            default :
                bufArray.append(d)
                //break
                
            }
        }
        
        
        processData("incoming data")
        
    }
    
//    func recvHeaderData(data:NSData) ->Int{
//        // only use display response status,recent request feature need
//        let r = data.rangeOfData(hData, options: NSDataSearchOptions.init(rawValue: 0), range: NSMakeRange(0, data.length))
//        if r.location != NSNotFound {
//            // body found
//            headerData.appendData( data.subdataWithRange(NSMakeRange(0, r.location)))
//            
//            reqInfo.respHeader = HTTPResponseHeader(data: headerData)
//            if let code = NSString.init(data: headerData, encoding: NSUTF8StringEncoding) {
//               //SKit.log("\(cIDString) resp \(code)",level: .Warning)
//            }
//            
//            //reqHeader = nil
//            //headerData = NSMutableData()
//            
//            return r.location+4 // https need delete CONNECT respond
//        }else {
//            headerData.appendData(data)
//            
//        }
//        return 0
//    }

//    func buildHTTPreqHeader(){
//        var httpdata:NSMutableData
//        guard let reqHeader = reqInfo.reqHeader else { return }
//        if reqInfo.rule.policy == .Direct{
//            httpdata = NSMutableData(data: reqHeader.headerData(nil))
//        }else {
//            httpdata = NSMutableData(data: reqHeader.headerData(reqInfo.proxy))
//        }
//        
//        let reqh = NSString.init(data: httpdata, encoding: NSUTF8StringEncoding)
//       //SKit.log("\(cIDString) http req header:\(reqh!)",level: .Debug)
//        if reqbody.length > 0 {
//            httpdata.appendData(reqbody)
//            reqbody = NSMutableData()
//        }
//       //SKit.log("\(cIDString) sendbuffer count \(bufArray.count)")
////        if let _ = respHeader {
////            bufArray.append(httpdata)
////        }else {
////            bufArray.insert(httpdata, atIndex: 0) //创建请求
////        }
//        bufArray.insert(httpdata, atIndex: 0)
//        //bufArray.append(httpdata) //创建请求
//        headerData = NSMutableData() //清除头部cache, 等待接收数据
//        //client_send_to_socks() //这个时候应该没有链接成功，成功后发送
//        
//    }
    
    func connect(){
        if connector == nil {
           //SKit.log("\(cIDString) connector don't init and init it",level: .Debug)
            configConnector()
        }
        //https direct don't need send CONNECT
        // ss proxy also don't need send CONNECT
        if reqInfo.mode == .HTTPS{
            //https
            if reqInfo.rule.policy == .Direct {
               //SKit.log("\(cIDString) \(reqInfo.mode) Direct don't need send CONNCET ",level: .Debug)
            }else {
                guard let p = reqInfo.proxy else {
                   //SKit.log("\(cIDString) can't find proxy",level: .Debug)
                    return
                }
                if p.type == .HTTP || p.type == .HTTPS {
                    //sendCONNECTRequest()
                    //buildHTTPreqHeader()
                    
                   
                    //c.connectionMode = self.reqInfo.mode
                    //sStat = .CONNECTING
                    //return
                }
            }
        }
        
        
        
    }
    override func processData(_ reason:String) {
       //SKit.log("\(cIDString) stat:\(httpStat) mode:\(reqInfo.mode) processData reason \(reason)",level: .Debug)
        if reqInfo.mode == .HTTPS{
            
           //SKit.log("\(cIDString) will sending data \(bufArray.count)", level: .Trace)
            //client_send_to_socks()
            if (bufArray.count > 0) {
                client_send_to_socks()
            }else {
                //if rTag == 0 {
                    client_socks_recv_initiate()
                //}
               
            }
            
            //SKit.log("\(cIDString) recv packet",level: .Debug)
            
        }else {
            //SKit.log("\(cIDString) prepare upgrade",level: .Warning)
            connect()
            
        }
        
        
    }

    
    
    override func client_send_to_socks(){
        let st = (reqInfo.status == .Established) || (reqInfo.status == .Transferring)
        if st  {
           //SKit.log("\(cIDString) now sending data buffer count:\(bufArray.count)",level: .Debug)
            super.client_send_to_socks()

        }else {
            if (!reqInfo.client_closed) {
                if rTag != 0  {
                    client_socks_recv_initiate()
                }
            }
        }
        
    }
    
    
    override func client_socks_handler(_ event:SocketEvent){
       assert(!reqInfo.socks_closed)
        switch event {
            
        case .event_ERROR:
            reqInfo.status = .Complete
            reqInfo.closereason = .closedError
           SKit.log("\(cIDString) \(reqInfo.transferTiming) RemoteError",level: .Trace)
            client_free_socks()
        case .event_UP:
            //assert(!reqInfo.socks_up)
            reqInfo.activeTime = Date()
            reqInfo.estTime = Date()
            SKit.log("\(cIDString) ESTABLISHED \(reqInfo.connectionTiming)",level: .Trace)
            reqInfo.status = .Established
            configClient_sent_func(pcb)
            reqInfo.socks_up = true
            
            _ = sendFakeCONNECTResponse()
            
            client_send_to_socks()
            
        //processData("ESTABLISHED")
        case .event_ERROR_CLOSED:
           SKit.log("\(cIDString) \(reqInfo.transferTiming) RemoteClosed",level: .Trace)
            //socks5 有问题
            //assert(reqInfo.socks_up)
            if reqInfo.estTime == Date.init(timeIntervalSince1970: 0){
                reqInfo.status = .Complete
            }
            
            //reqInfo.socks_up = false
            //reqInfo.socks_closed = true
            reqInfo.eTime = Date() 
            // 这个时候buf 里可能有没发完的data
            client_free_socks()
            
            break
            
        }
    }
//    override func connectorDidDisconnect(connector:Connector ,withError:NSError){
//       //SKit.log("\(cIDString) \(reqInfo.traffice.tx):\(reqInfo.traffice.rx) \(withError)",level: .Debug)
//        debugLog("connectorDidDisconnect \(self.reqInfo.url)" + withError.description)
//        client_socks_handler(.EVENT_ERROR_CLOSED)
//    }
    override func didReadData(_ data: Data, withTag: Int, from: Xcon) {
        
      
        //reqInfo.status = .Transferring
        
        //reqInfo.updateSpeed(UInt(data.length),stat: true)
        reqInfo.updaterecvTraffic(data.count)
        //reqInfo.traffice.addRx(data.length)
        //SKit.log("\(cIDString) time:\(reqInfo.activeDesc) tag:\(tag):\(rTag) receive Data length  \(data.length) flow:\(reqInfo.traffice.tx):\(reqInfo.traffice.rx) ",level: .Trace)
        //critLock.lockBeforeDate( NSDate( timeIntervalSinceNow: 0.05))
        rTag += 1
        //RawRepresentable
        //critLock.unlock()
        //debugLog("\(cIDString) didread")
        #if LOGGER
            reqInfo.recvData.append(data)
        #endif

        let count = data.count
        for p in data.regions {
            socks_recv_bufArray.append(p)
        }
      
        client_socks_recv_handler_done(count)
        //processData("didReadData")
        
    }
    override func checkStatus() {
        //SKit.log("\(cIDString) header queue:\(reqHeaderQueue.count) index:\(requestIndex) ",level: .Debug)
        if let _ = reqInfo.respHeader {
            //SKit.log("\(cIDString) resp:\(h.mode) \(h.bodyLeftLength) ",level: .Debug)
            if socks_recv_bufArray.count == 0 && bufArray.count == 0 && reqInfo.traffice.rx > 0 {
                if SFOpt.shouldKepp(host: reqInfo.host) {
                    if reqInfo.idleTimeing > SFOpt.HTTPLongConnect{
                        SKit.log("\(cIDString) \(reqInfo.host)  timeout1 ",level: .Warning)
                        client_free_socks()
                        
                    }
                }else {
                    if reqInfo.idleTimeing > SFOpt.HTTPSTimeout{
                        SKit.log("\(cIDString) \(reqInfo.host)  timeout1 ",level: .Warning)
                        client_free_socks()
                        
                    }
                }
               
            }else if  reqInfo.idleTimeing > SFOpt.HTTPSTimeout {
                SKit.log("\(cIDString) \(reqInfo.host)  timeout2 ",level: .Warning)
                client_free_socks()

            }
            
        }else {
            if  reqInfo.idleTimeing > SFOpt.HTTPNoHeaderTimeout {
                SKit.log("\(cIDString) \(reqInfo.host)  no resp header disconnect ",level: .Warning)
                client_free_socks()
                
            }
        }
        
        //super.checkStatus()
    }
    override func memoryWarning(_ level:DispatchSource.MemoryPressureEvent) {
        let result = reqInfo.shouldClose()
        if result {
            if socks_recv_bufArray.count == 0 && bufArray.count == 0{
                SKit.log("\(reqInfo.host) idle \(reqInfo.idleTimeing) to long close socket",level: .Warning)
                client_free_socks()
            }
        }else {
            SKit.log("\(reqInfo.host) recv memoryWarning buffer recv:\(socks_recv_bufArray) send:\(bufArray) ",level: .Warning)
            SKit.log("\(cIDString) \(reqInfo.host)   will close recv:\(socks_recv_bufArray.count) send: \(bufArray.count)",level: .Warning)
            client_free_socks()
        }
        
        
    }
}
