//
//  File.swift
//  SFSocket
//
//  Created by yarshure on 2017/8/21.
//  Copyright © 2017年 Kong XiangBo. All rights reserved.
//

import Foundation
import Darwin
class GCDTunnelConnection: TUNConnection {
    var socketfd:Int32 = 0
    var headerData:Data = Data()
    var httpStat:HTTPConnectionState = .httpDefault
    var requestIndex:UInt = 0
    var reqHeaderQueue:[SFHTTPRequestHeader] = []
     weak var manager:SFTCPConnectionManager?
    
    var recvHeaderData:Data = Data()
    
    var currentBodyLength:UInt = 0
    var totalRecvLength:UInt = 0
    var currentBobyReadLength:UInt = 0
    
    init(sfd:Int32,rip:String,rport:UInt16,dip:String,dport:UInt16) {
        //this info is for mac iden process info
        let remote_addr  = IPAddr(i: inet_addr(rip),p: rport)
        let local_addr  = IPAddr(i: inet_addr(dip), p: dport)
        let info:SFIPConnectionInfo = SFIPConnectionInfo.init(t: local_addr , r:remote_addr )
        //manager = m
        self.socketfd = sfd
        
        super.init(i:info)
        self.reqInfo.mode  = .HTTP
        httpStat = .httpReqHeader
    }
    var cIDString:String {
        get {
            #if DEBUG
                return "[GCDTunnelConnection-\(reqInfo.reqID)-\(info.tun.port)" + "]" //self.classSFName()
            #else
                //-\(info.tun.port)-\(pcb)
                return  "[" + objectClassString(self) + "-\(reqInfo.reqID)" + "]" //self.classSFName()
            #endif
        }
    }
    func updateReq(_ req:SFRequestInfo){
        if req == reqInfo {
            // 有bug
            SKit.log("\(cIDString) reqInfo error",level: .Error)
        }
        req.mode = .HTTP
        req.app = reqInfo.app
        req.remoteIPaddress = reqInfo.remoteIPaddress
        req.localIPaddress = reqInfo.localIPaddress
        req.interfaceCell = reqInfo.interfaceCell
        req.traffice.tx = 0
        req.traffice.rx = 0
        let now =  Date()
        req.sTime = now
        req.estTime = now
        req.status  = .Transferring
        //req.host = reqInfo.host
        //req.url = reqHeader.Url
        req.started = reqInfo.started
        req.waitingRule = false
        req.ruleStartTime = now
        
        req.proxy = reqInfo.proxy
        req.rule = reqInfo.rule
        
        
        
        req.inComingTime = now
        req.activeTime = now
        //req.pcb_closed = false
        req.client_closed = false
        req.socks_up = true
        req.socks_closed = false
        
        //pass change to use db
        //SFTCPConnectionManager.manager.addReqInfo(req)
        
        
    }
    
    func processBufer(_ d:Data,req:SFRequestInfo,enqueue:Bool) -> Bool {
        let len = d.count
        let r = d.range(of:hData, options: Data.SearchOptions.init(rawValue: 0), in: Range(0 ..< len))
        if let r = r {
            // body found
            
            headerData.append( d.subdata(in: Range(0 ..< r.lowerBound)))
            SKit.log("\(cIDString) header-- \(headerData as Data)", level: .Debug)
            //MARK: - todo fixme
            guard let reqHeader   = SFHTTPRequestHeader(data: headerData as Data) else {
                SKit.log("\(cIDString) parser header error \(headerData)",level: .Error)
                return false
            }
            
            // host rewrite
            if reqHeader.checkRewrite() {
                SKit.log("rewrite \(reqHeader.Host) to \(reqHeader.Host)",level: .Debug)
            }
            headerData.count = 0
            
            
            SKit.log("\(cIDString) req \(reqHeader.method)   \(reqHeader.Url) http://\(reqHeader.Host)\(reqHeader.genPath())\n)",level: .Debug)
            
            forceSend = reqHeader.forceSend()
            
            
            
            
            //是否进入队列
            // 头数据优先进发送队列
            if enqueue {
                SKit.log("\(cIDString) pipeline enqueue header ",level: .Trace)
                reqHeaderQueue.append(reqHeader)
            }else {
                req.url = reqHeader.Url
                
                req.app = reqHeader.app
                let httpdata = reqHeader.headerData(nil)
                //why don't add to bufArray, header need fix url
                if reqHeader.method != .CONNECT {
                    
                    bufArray.append(httpdata)
                }else {
                    SKit.log("\(cIDString) \(reqInfo.url) ####### CONNECT don't need send header",level: .Debug)
                }
                req.reqHeader = reqHeader
            }
            // 头数据优先进发送队列，body再进
            if r.lowerBound + 4 < len {
                let body = d.subdata(in: Range(r.lowerBound+4 ..< len ))
                //need test
                bufArray.append(body)
                
                reqHeader.bodyLeftLength -= body.count
                
                SKit.log("\(cIDString) \(reqHeader.contentLength) left:\(reqHeader.bodyLeftLength)",level: .Debug)
            }else{
                
                SKit.log("\(cIDString) \(reqHeader.Url) no data left for http request body",level: .Debug)
            }
            
            if reqHeader.bodyReadFinish() {
                //requestIndex += 1 //no body or body not full
                //httpStat = .HttpReqSending
            }else {
                httpStat = .httpReqBody
            }
            //这个时候有reqhead 了
            if reqHeader.method == .CONNECT {
                httpStat = .httpReqSending //不用收body 了
                SKit.log("\(cIDString) HTTP CONNECT \(req.url)",level: .Trace)
            }
            SKit.log("\(cIDString) http stat \(httpStat)",level: .Debug)
            
        }else {
            
            headerData.append(d)
            SKit.log("\(cIDString) don't found header ,wait req header buffer len:\(headerData.count)",level: .Warning)
            return false
        }
        return true
        
    }
    func currentRequest() ->SFRequestInfo{
        SKit.log("\(cIDString)  index:\(requestIndex),\(reqHeaderQueue.count)",level: .Debug)
        //来header 或者body 会调用这个方法
        
        if reqHeaderQueue.count > 0  { // pipeling , other one by one
            SKit.log("\(cIDString) http pipeline support not full tested",level: .Warning)
            if let resp = reqInfo.respHeader {
                if resp.finished {
                    reqInfo.status = .Complete
                    manager!.saveTunnelConnectionInfo(self) //write db
                    SKit.log("\(cIDString) pipeline create SFRequestInfo",level: .Debug)
                    let req   = SFRequestInfo.init(rID: reqInfo.reqID, sID:requestIndex )
                    let header = reqHeaderQueue.remove(at: 0)
                    req.reqHeader = header
                    req.url = header.Url
                    req.app = header.app
                    let httpdata = header.headerData(nil)
                    //why don't add to bufArray, header need fix url
                    if header.method != .CONNECT {
                        SKit.log("\(cIDString) \(header.Url) pepeline add header data",level: .Warning)
                        bufArray.append(httpdata)
                    }else {
                        SKit.log("\(cIDString) \(reqInfo.url) ####### CONNECT don't need send header",level: .Error)
                    }
                    if recvHeaderData.count != 0 {
                        recvHeaderData.replaceSubrange(Range(0 ..< recvHeaderData.endIndex), with: Data())
                    }
                    updateReq(req)
                    reqInfo = req
                    
                }
            }
        }else {
            if let _ = reqInfo.respHeader {
                if reqInfo.respReadFinish  {
                    reqInfo.status = .Complete
                    manager!.saveTunnelConnectionInfo(self) //write db
                    SKit.log("\(cIDString) HTTP keep-alive create SFRequestInfo",level: .Warning)
                    let req   = SFRequestInfo.init(rID: reqInfo.reqID, sID:requestIndex )
                    if recvHeaderData.count != 0 {
                        recvHeaderData.replaceSubrange(Range(0 ..< recvHeaderData.endIndex), with: Data())
                    }
                    updateReq(req)
                    reqInfo = req
                    
                }else {
                    SKit.log("\(cIDString) \(reqInfo.url) read finishd? ",level: .Info)
                    reqInfo.status = .Complete
                    manager!.saveTunnelConnectionInfo(self) //write db
                    SKit.log("\(cIDString) HTTP keep-alive create SFRequestInfo",level: .Warning)
                    let req   = SFRequestInfo.init(rID: reqInfo.reqID, sID:requestIndex )
                    if recvHeaderData.count != 0 {
                        recvHeaderData.replaceSubrange(Range(0 ..< recvHeaderData.endIndex), with: Data())
                    }
                    updateReq(req)
                    reqInfo = req
                    SKit.log("\(cIDString) reqinfo have reset ",level: .Info)
                }
            }else {
                if reqInfo.reqHeader == nil {
                    SKit.log("\(cIDString) reqHeader incoming ",level: .Info)
                    //                    reqInfo.status = .Complete
                    //                    manager!.saveConnectionInfo(self) //write db
                    //                    SKit.log("\(cIDString) HTTP keep-alive create SFRequestInfo",level: .Warning)
                    //                    let req   = SFRequestInfo.init(rID: reqInfo.reqID, sID:requestIndex )
                    //
                    //                    updateReq(req)
                    //                    reqInfo = req
                    //                    SKit.log("\(cIDString) reqinfo have reset ",level: .Info)
                }else {
                    SKit.log("\(cIDString) \(reqInfo.url) pipeline? not recv header ",level: .Info)
                }
                
            }
            
        }
        return reqInfo
        
    }
    
    var statusString:String {
        get {
            return "reqIndex:\(requestIndex) "
        }
    }
    
    
    func incommingData(_ d:Data ,len:Int){
        //NSLog("http recv %@", d)
        
        //SKit.log("\(cIDString) incoming data len \(d as NSData) \(len)",level: .Debug) // \(d)
        SKit.log("\(cIDString) bufArray length: \(bufArray.count)",level: .Trace)
        if d.count > 0 {
            
            #if LOGGER
                reqInfo.sendData.append(d)
            #endif
        }
        
        
        switch httpStat {
        case .httpDefault:
            httpStat = .httpReqHeader
            //SKit.log("\(cIDString) connection init",level: .Debug)
            return
        case .httpReqHeader:
            
            let  currentReqInf:SFRequestInfo = currentRequest()
            currentReqInf.activeTime =   Date()
            if currentReqInf.reqHeader == nil {
                if processBufer(d,req: currentReqInf,enqueue: false) == false {
                    SKit.log("\(cIDString) req header not finishd ",level: .Warning)
                    return
                }else {
                    SKit.log("\(cIDString) \(requestIndex) header Fin \(currentReqInf.reqHeader!.mode)",level: .Trace)
                    SKit.log("\(cIDString) req:\(reqInfo.url)",level: .Info)
                    
                }
                
                //updateReq(currentReqInf)
            }else {
                
                SKit.log("\(cIDString) HttpReqHeader  incoming date,shoud not go here http pipeline? \(currentReqInf.url)",level: .Trace)
                if processBufer(d,req: currentReqInf,enqueue: true) == false {
                    SKit.log("\(cIDString) pipeline req header not finishd ",level: .Warning)
                    return
                }else {
                    SKit.log("\(cIDString) \(requestIndex) pipeline header Fin",level: .Trace)
                    
                }
                if let header = currentReqInf.reqHeader {
                    if header.method == .CONNECT {
                        
                        SKit.log("\(cIDString) HTTP CONNECT \(reqInfo.url) pipeline should not have CONNECT",level: .Error)
                    }
                }
                
                break
                //fatalError()
            }
            
        case .httpReqBody:
            //等待Body 读完
            //如果upload大文件呢？ 3M,5M,这样的情况也不太可能
            //Sequences of GET and HEAD requests can always be pipelined.
            //这里不能是pipeline
            if reqHeaderQueue.count > 0 {
                SKit.log("\(cIDString) pipeline should not have body data",level: .Error)
                return
            }
            let  currentReqInf:SFRequestInfo = reqInfo// currentRequest()
            SKit.log("\(cIDString) HttpReqBody connection Body",level: .Debug)
            guard let req = currentReqInf.reqHeader else  {return }
            //可能有超出问题
            if d.count > req.bodyLeftLength {
                SKit.log("\(cIDString) \(currentReqInf.url) incoming data length > req.bodyLeftLength",level: .Notify)
            }
            
            bufArray.append(d)
            req.bodyLeftLength -= d.count
            if req.bodyReadFinish() {
                
                httpStat = .httpReqHeader
                SKit.log("\(cIDString) Body Finish",level: .Debug)
            }else {
                let left = req.bodyLeftLength
                
                SKit.log("\(cIDString) Body left:\(left)",level: .Debug)
            }
            
            break
        // 直接发送，和TCP 差不多了
        default :
            //存在一个request
            if let header = reqInfo.reqHeader {
                if header.method == .CONNECT {
                    bufArray.append(d)
                    break
                }else {
                    SKit.log("\(cIDString)  \(header.method) have data \(d) incoming",level: .Trace)
                }
            }else {
                SKit.log("\(cIDString) no  request header error",level: .Error)
            }
            
        }
        
        processData("incoming data")
        
    }
    func scanBuffer() ->Range<Data.Index>? {
        //check HTTP/ver
        //check \r\n\r\n
        //recvHeaderData 可能有html 数据
        if let r1 = checkBufferHaveData(recvHeaderData, data: http) {
            if let r2 = checkBufferHaveData(recvHeaderData, data: hData){
                SKit.log("\(cIDString) find HTTP and hData length: \(r2.lowerBound)",level: .Debug)
                
                //let left = recvHeaderData.length - len
                return Range( r1.lowerBound ..< r2.lowerBound)
            }else {
                SKit.log("\(cIDString) only find HTTP \(r1.lowerBound) \(recvHeaderData)",level: .Debug)
            }
        }else {
            //bug here
            SKit.log("\(cIDString) only find HTTP and location != 0 \(recvHeaderData)",level: .Debug)
        }
        
        return nil
    }

    func reqsonseBodyLeft(_ req:SFRequestInfo) -> Int {
        guard let header = req.respHeader else {return -1}
        return header.bodyLeftLength
        
    }
    
    func respHeaderRecved(_ req:SFRequestInfo) ->Bool {
        if let _ = req.respHeader {
            return true
        }else {
            return false
        }
    }
    
    func processRecvData(_ data:Data,currentReq:SFRequestInfo) {
        // NSLog("Req:%d recvHeaderData %d", reqInfo.reqID,recvHeaderData.length)
        // 只是parser 而以
        totalRecvLength += UInt(data.count)
        
        //        if requests.count == 0 && reqInfo.respHeader != nil{
        //            recvHeaderData.length = 0
        //            //需要判断是否完成
        //             SKit.log("\(cIDString) resp have header and don't have sub requests",level: .Debug)
        //            return
        //        }
        //主要是为了解析头部使用，和发现包结尾
        SKit.log("\(cIDString) recv Data:\(data.count) buffer_len:\(recvHeaderData.count)",level: .Debug)
        
        SKit.log("\(cIDString) processRecvData:\(data)",level:.Debug)
        var used_length = 0
        recvHeaderData.append(data)
        if currentReq.respHeader == nil {
            
            guard let  range = scanBuffer() else {
                return
            }
            
            used_length += range.lowerBound
            
            
            SKit.log("\(cIDString) respsonseIndex:\(requestIndex) found header",level: .Debug)
            let temp = recvHeaderData.subdata(in: range)
            used_length += 4 //let left_len = recvHeaderData.length - len - 4 //\r\n\r\n
            if let x = SFHTTPResponseHeader(data: temp) {
                
                SKit.log("\(cIDString) respsonseIndex:\(requestIndex) mode:\(x.mode) body length: \(x.contentLength) ",level: .Info)
                
                SKit.log("\(cIDString) params: \(x.params)",level: .Trace)
                
                currentReq.respHeader  = x
                
                
                let left = recvHeaderData.subdata(in: Range(used_length ..< recvHeaderData.count))
                
                
                
                
                let (fin, used)  = currentReq.checkReadFinish(left)
                if  fin{ //no content-length
                    //if currentReq != reqInfo {
                    SKit.log("\(cIDString):\(requestIndex) body  finish \(x.mode)",level: .Trace)
                    requestIndex += 1
                    //x.finished = true
                    currentReq.respReadFinish = true
                    //currentReq.status = .Complete
                    //不能close
                }else {
                    SKit.log("\(cIDString): \(requestIndex) body not finish \(currentReq.respHeader!.bodyLeftLength) \(x.mode)",level: .Debug)
                    SKit.log("\(cIDString) code \(currentReq.respHeader!.sCode)",level: .Debug)
                }
                used_length += used
                if left.count - used > 0 {
                    
                    
                    let x  = left.subdata(in: Range(used ..< left.count))
                    recvHeaderData = x
                    
                    SKit.log("\(cIDString) have new header \(recvHeaderData)",level: .Debug)
                }else {
                    recvHeaderData.replaceSubrange(Range(0 ..< recvHeaderData.endIndex), with: Data())
                }
                
                SKit.log("\(cIDString) used \(used_length)",level: .Verbose)
            }else {
                SKit.log("\(temp) parser failure",level: .Error)
            }
            
        }else {
            
            guard let h = currentReq.respHeader else {return }
            if h.mode == .TransferEncoding {
                //recvHeaderData.append(data)
                SKit.log("\(cIDString) \(h.bodyLeftLength) \(currentReq.url)   TransferEncoding mode",level: .Debug)
                
                let (fin, used) = currentReq.checkReadFinish(recvHeaderData)
                if fin {
                    SKit.log("\(cIDString):\(requestIndex) mode:\(h.mode) body  finish \(used) ",level: .Warning)
                    //h.finished = true
                    currentReq.respReadFinish = true
                    requestIndex += 1
                }else {
                    SKit.log("\(cIDString): \(requestIndex) body not finish \(used) \(h.bodyLeftLength) ",level: .Trace)
                }
                if recvHeaderData.count - used > 0 {
                    
                    let x  = recvHeaderData.subdata(in:Range(used ..< recvHeaderData.count))
                    recvHeaderData = x
                }else {
                    recvHeaderData.replaceSubrange(Range(0 ..< recvHeaderData.endIndex), with: Data())
                }
                //h.bodyLeftLength -= data.length
            }else  if h.mode == .ContentLength{ //fixed reqInfo error bug
                //recvHeaderData.append(data)
                let need = reqsonseBodyLeft(currentReq)
                SKit.log("\(cIDString) \(requestIndex) ContentLength left length: \(need)",level: .Trace)
                let (fin, used)  = currentReq.checkReadFinish(recvHeaderData)
                
                if fin {
                    //currentReq.status = .Complete
                    SKit.log("\(cIDString) \(requestIndex) mode:\(h.mode) body Fin ",level: .Trace)
                    //h.finished = true
                    currentReq.respReadFinish = true
                    requestIndex += 1
                }else {
                    SKit.log("\(cIDString) \(requestIndex) unFin left \(currentReq.respHeader!.bodyLeftLength)",level: .Debug)
                }
                if recvHeaderData.count - used > 0 {
                    let x  = recvHeaderData.subdata(in: Range(used ..< recvHeaderData.count))
                    recvHeaderData = x
                }else {
                    recvHeaderData.replaceSubrange(Range(0 ..< recvHeaderData.endIndex), with: Data())
                }
                
            }else {
                let (_, used)  = currentReq.checkReadFinish(data)
                SKit.log("\(cIDString) \(requestIndex) mode:\(h.mode) content_len:\(h.contentLength) left:\(h.bodyLeftLength) used: \(used)",level: .Trace)
            }
            
        }
        if recvHeaderData.count > 1024*8{
            //fixed one bug
            if let respHeader = reqInfo.respHeader {
                SKit.log("\(cIDString) recv buffer too bigger mode:\(respHeader.mode) \(recvHeaderData.count)",level: .Debug)
            }else {
                SKit.log("\(cIDString) recv buffer too bigger length:\(recvHeaderData.length) will clear cache",level: .Error)
            }
            
            recvHeaderData.replaceSubrange(Range(0 ..< recvHeaderData.endIndex), with: Data())
        }
    }
    func connect(){
        if connector == nil {
            //SKit.log("\(cIDString) connector don't init and init it",level: .Debug)
            configConnector()
        }
        if let p = reqInfo.proxy {
            if  p.type == .HTTP || p.type == .HTTPS{
                //send connect
                //MARK : -fixme
                //let c = connector as! HTTPProxyConnector
                //c.reqHeader = reqInfo.reqHeader
            }
        }
        
    }
    
    func processData(_ reason:String) {
        SKit.log("\(cIDString) stat:\(httpStat.description) mode:\(reqInfo.mode) prcessData reason \(reason)",level: .Debug)
        //NSLog("\(cIDString) processData \(reqInfo.url) \(httpStat.description)")
        
        if !reqInfo.started {
            guard let head = reqInfo.reqHeader else { return }
            SKit.log("\(cIDString) \(head.params)",level:.Debug)
            //if connertor
            if let _ = connector {
                //SKit.log("\(cIDString) \(httpStat.description)",level:.Trace)
                SKit.log("\(cIDString) connector  setup OK",level: .Debug)
            }else {
                SKit.log("\(cIDString) will process rule re enter",level: .Debug)
                configConnector() //重入bug ,不允许
            }
            reqInfo.started = true
        }else {
            SKit.log("\(cIDString) connected  sending",level: .Debug)
            client_send_to_socks()
        }
        
    }
    
     func client_send_to_socks(){
        let st = (reqInfo.status == .Established) || (reqInfo.status == .Transferring)
        if st  {
            if bufArray.count > 0{
                SKit.log("\(cIDString) now sending data buffer count:\(bufArray.count)",level: .Debug)
                fatalError()
                client_send_to_socks()
                
            }else {
                //if rTag == 0  {
                client_socks_recv_initiate()
                //}
                
            }
        }else {
            SKit.log("\(cIDString) not ESTABLISHED ",level: .Debug)
        }
        
    }
    
    
    func client_socks_handler(_ event:SocketEvent){
        switch event {
            
        case .event_ERROR:
            reqInfo.status = .Complete
            reqInfo.closereason = .closedError
            //            reqInfo.socks_up = false
            reqInfo.socks_closed = true
            //SKit.log("\(cIDString) \(reqInfo.transferTiming) RemoteError",level: .Debug)
            client_free_socks()
        case .event_UP:
            assert(!reqInfo.socks_up)
            reqInfo.activeTime = Date() as Date
            reqInfo.estTime = Date() as Date
            
            //            if !reqInfo.client_closed {
            //                configClient_sent_func(pcb)
            //            }
            
            reqInfo.socks_up = true
            //SKit.log("\(cIDString) ESTABLISHED \(reqInfo.connectionTiming)",level: .Debug)
            if let header = reqInfo.reqHeader {
                if header.method == .CONNECT{
                    _ = sendFakeCONNECTResponse()
                }
            }
            //NSLog("%@ Established", reqInfo.url)
            reqInfo.status = .Established
            
            //client_socks_recv_initiate()
            client_send_to_socks()
            //            if (!reqInfo.client_closed) {
            //                client_socks_recv_initiate()
            //            }
        //prcessData("ESTABLISHED")
        case .event_ERROR_CLOSED:
            //SKit.log("\(cIDString) \(reqInfo.transferTiming) RemoteClosed",level: .Debug)
            //protocol error
            //assert(reqInfo.socks_up)
            reqInfo.status = .Complete
            //reqInfo.socks_up = false
            reqInfo.socks_closed = true
            reqInfo.eTime = Date() as Date
            // 这个时候buf 里可能有没发完的data
            client_free_socks()
            
            break
            
        }
    }
    override func  didReadData(_ data: Data, withTag: Int, from: TCPSession) {
        
        
        //reqInfo.status = .Transferring
        guard let _ = reqInfo.reqHeader else {return}
        let  currentReq:SFRequestInfo = reqInfo
        
        //SKit.log("\(cIDString) time:\(reqInfo.transferTiming) tag:\(tag):\(rTag) receive Data length:\(data):\(data.length) flow:\(currentReq.traffice.tx):\(currentReq.traffice.rx) ",level: .Debug)
        SKit.log("\(cIDString) time:\(reqInfo.transferTiming) tag:\(tag):\(rTag) receive Data length:\(data.length):\(data.length) flow:\(currentReq.traffice.tx):\(currentReq.traffice.rx) ",level: .Debug)
        //critLock.lockBeforeDate( NSDate( timeIntervalSinceNow: 0.05))
        rTag += 1
        //NSLog("%@,%d didReadData", cIDString,tag)
        //debugLog(cIDString + "didReadData " + reqInfo.url)
        //RawRepresentable
        //critLock.unlock()
        //就差这里了
        #if LOGGER
            reqInfo.recvData.appendData(data)
        #endif
        
        
        
        if reqInfo.status == .Complete {
            SKit.log(cIDString + "didReadData done Complete 000 " + reqInfo.url,level: .Debug)
        }
        
        if reqInfo.mode == .HTTPS{
            //currentReq.updateSpeed(UInt(data.length),stat: true)
            currentReq.updaterecvTraffic(data.count)
        }else {
            //currentReq.updateSpeed(UInt(data.length),stat: false)
            
            currentReq.updaterecvTraffic(data.count)
            
            //5K
            //SKit.log("\(cIDString) http recv data length:\(data.length)",level: .Debug)
            //leak
            processRecvData(data, currentReq: currentReq)
            if let resp =  currentReq.respHeader{
                
                if let location = resp.params["Location"] {
                    //currentReq.reqHeader!.location = location
                    //disable this build
                    //disable this feature
                    if !location.hasPrefix("https") && !location.hasSuffix("http://ipv4.google") {
                        SKit.log("\(cIDString) status \(resp.sCode) location:\(location)",level: .Debug)
                        //processLocationEvent(location)
                        //return
                    }else {
                        SKit.log("\(cIDString)  location:\(location) http->https don't support",level: .Debug)
                    }
                    
                }
                
                
            }
        }
        //        if socks_recv_bufArray.count == 0 {
        //            socks_recv_bufArray  = data
        //        }else {
        //            socks_recv_bufArray.append(data)
        //        }
        data.enumerateBytes { (ptr:UnsafeBufferPointer<UInt8>,index: Data.Index, flag:inout Bool) in
            socks_recv_bufArray.append(ptr)
        }
        
        client_socks_recv_handler_done(data.count)
        
        
        
        //prcessData("didReadData")
        
    }
    func processLocationEvent(_ location:String){
        
        //write record
        if let m = manager {
            m.saveTunnelConnectionInfo(self)
            
        }
        //create new header data
        
        if let request = reqInfo.reqHeader {
            //
            var hostChanged = false
            if let req = reqInfo.reqHeader {
                if let u = URL(string:location) {
                    if let h =  u.host {
                        if h != req.Host{
                            hostChanged = true
                        }
                    }
                    if !hostChanged{
                        if let port = u.port {
                            if port != req.Port {
                                hostChanged = true
                            }
                        }
                    }
                }
            }
            if reqInfo.respReadFinish || hostChanged {
                SKit.log("\(cIDString) respReadFinish, process 302 ", level: .Debug)
                let data = request.updateWithLocation(location)
                if bufArray.count > 0{
                    bufArray.removeAll()
                }
                
                
                //disconnect socket
                if request.hostChanged {
                    SKit.log("\(cIDString) hostChanged, disconnect socket", level: .Debug)
                    if connector != nil  {
                        connector?.delegate = nil
                        connector?.forceDisconnect()
                        connector = nil
                    }
                }else {
                    SKit.log("\(cIDString) not change", level: .Debug)
                }
                //占不了多少内存
                bufArray.append(data)
                SKit.log("\(cIDString) \(data)", level: .Debug)
                let req   = SFRequestInfo.init(rID: reqInfo.reqID, sID:requestIndex )
                //reset status
                //req.subID += 1
                
                //http may location to https
                //这是1个复杂的问题
                // 转给应用处理
                req.mode = .HTTP
                
                req.remoteIPaddress = ""
                req.localIPaddress = ""
                req.interfaceCell = reqInfo.interfaceCell
                let now =  Date()
                req.sTime = now as Date
                req.estTime = Date.init(timeIntervalSince1970: 0) as Date
                req.traffice.rx = 0
                req.traffice.tx = 0
                
                //req.host = request.host
                req.url = request.location
                
                req.waitingRule = false
                req.ruleStartTime = now as Date
                
                req.proxy = reqInfo.proxy
                req.rule = reqInfo.rule
                
                
                
                req.inComingTime = now as Date
                req.activeTime = now as Date
                //req.pcb_closed = false
                
                if request.hostChanged {
                    req.status  = .Start
                    req.client_closed = false
                    req.socks_up = false
                    req.started = false
                    req.socks_closed = false
                }else {
                    //req.status  = .Start
                    req.client_closed = false
                    req.socks_up = true
                    req.started = reqInfo.started
                    req.socks_closed = false
                    req.status = .Established
                }
                
                recvHeaderData = Data() //reset
                req.reqHeader = request
                req.respHeader = nil
                self.reqInfo = req
                
            }else {
                SKit.log("\(cIDString)  302 Location have no use info ", level: .Debug)
            }
            
            processData("processLocationEvent")
        }else {
            SKit.log("\(cIDString) header error", level: .Debug)
        }
        
        
        
        
    }
    override func didWriteData(_ data: Data?, withTag: Int, from: TCPSession){
        SKit.log("\(cIDString) didWriteDataWithTag \(withTag) \(tag)",level: .Debug)
        //NSLog("currrent tag: \(tag) == \(_tag)")
        guard let _ = reqInfo.reqHeader else {return}
        let currentReq:SFRequestInfo = reqInfo
        
        currentReq.status = .Transferring
        //debugLog("\(cIDString) didWriteDataWithTag")
        currentReq.activeTime = Date() as Date
        
        //let d = bufArray.removeFirst()
        let x = Int64(withTag)
        if let len = bufArrayInfo[x] {
            client_socks_send_handler_done(len)
            bufArrayInfo.removeValue(forKey: x)
            reqInfo.updateSendTraffic(len)
        }else {
            SKit.log("\(cIDString) not find send packet", level: .Debug)
        }
        
       
        
        tag += 1
        
        
        processData("didWriteData")
    }
    
    
    func client_socks_recv_initiate(){
        
        assert(!reqInfo.client_closed)
        assert(!reqInfo.socks_closed)
        assert(reqInfo.socks_up)
        
        //        if let _ = reqInfo.respHeader{
        //            if reqInfo.respReadFinish {
        //                SKit.log("\(cIDString) respReadFinish ,wait next read", level: .Warning)
        //                return
        //            }
        //        }
        //
        if reqInfo.status != .Complete  {
            
            guard let c = connector else {
                SKit.log("\(cIDString) socket dead , exit ", level: .Error)
                client_free_socks()
                return
            }
            //let buf_size:UInt =  SFEnv.SOCKS_RECV_BUF_SIZE
            
            
            if socks_recv_bufArray.count > 0 {
                SKit.log("\(cIDString) buffer have data need write to lwip,recv waiting",level: .Debug)
                //client_tcp_output()
                //NSLog("%@ client_socks_recv_send_out", cIDString)
                 client_socks_recv_send_out()
            }else {
                if reqInfo.status !=  .RecvWaiting {
                    
                    
                    
                    if bufArray.count > 0 {
                        client_send_to_socks()
                    }else {
                        //fixme have bug
                        guard let header = reqInfo.reqHeader else {
                            return
                        }
                        if let resp = reqInfo.respHeader, resp.shouldColse2(hostname: header.Host) == true {
                            if reqInfo.respReadFinish {
                                SKit.log("\(cIDString)  HTTP STATUS:302 close now respReadFinish",level:.Notify)
                                
                            }else {
                                SKit.log("\(cIDString)  HTTP STATUS:302 close now not respReadFinish",level:.Notify)
                            }
                            
                            //client_free_socks()
                            let e = NSError.init(domain: "com.yarshure.surf", code: 0, userInfo: ["reason":"status:302 close"])
                            //self.connector!.delegate = nil
                            SKit.log("\(e.localizedDescription) \(self.reqInfo.url)",level: .Verbose)
                            //reqInfo.status = .Complete
                            if let connector = connector{
                                connector.forceDisconnect()
                            }
                            
                        }else {
                            c.readDataWithTag(rTag)
                        }
                        
                    }
                    
                }else {
                    SKit.log("\(cIDString)  recv waiting",level:.Trace)
                    
                }
            }
        }else {
            SKit.log("\(cIDString) request Finished ,shoud  close?",level: .Debug)
            //单个请求
            if let h = reqInfo.respHeader {
                if h.shouldClose() {
                    SKit.log("\(cIDString) request Finished close socket",level: .Warning)
                    client_free_socks()
                }else {
                    SKit.log("\(cIDString) request Finished should not go here",level: .Trace)
                }
            }
            
        }
        
    }
    func checkStatus() {
        //
        if socks_recv_bufArray.count > 1024*50{
            SKit.log("\(cIDString) recv queue too long \(socks_recv_bufArray.length)  ",level: .Warning)
            client_socks_recv_send_out()
            return
        }
        if let h = reqInfo.respHeader {
            //SKit.log("\(cIDString) resp:\(h.mode) \(h.bodyLeftLength) ",level: .Debug)
            if let alive  = h.params["Connection"], alive == "close" {
                if socks_recv_bufArray.count == 0 && bufArray.count == 0  {
                    if reqInfo.respReadFinish {
                        if reqInfo.idleTimeing > SFOpt.HTTPSTimeout{
                            SKit.log("\(cIDString) \(reqInfo.host)  timeout , will close 1",level: .Warning)
                            client_free_socks()
                            
                        }
                    }else {
                        if reqInfo.idleTimeing > SFOpt.HTTPVeryTimeout {//15
                            SKit.log("\(cIDString) \(reqInfo.host)  timeout , will close 2",level: .Warning)
                            client_free_socks()
                            
                        }
                    }
                    
                }else {
                    if reqInfo.idleTimeing > SFOpt.HTTPVeryTimeout {
                        SKit.log("\(cIDString) \(reqInfo.host)  timeout , will close 3",level: .Warning)
                        client_free_socks()
                        
                    }
                }
            }else {
                if let url = h.params["Location"] {
                    SKit.log("\(cIDString) code \(h.sCode) change to \(url)", level: .Debug)
                    client_free_socks()
                }
                if socks_recv_bufArray.count == 0 && bufArray.count == 0 {
                    
                    if reqInfo.respReadFinish  {
                        if reqInfo.idleTimeing > SFOpt.HTTPSTimeout{
                            SKit.log("\(cIDString) \(reqInfo.host)  timeout , will close 4",level: .Warning)
                            client_free_socks()
                            
                        } else {
                            if reqInfo.idleTimeing > SFOpt.HTTPVeryTimeout{
                                SKit.log("\(cIDString) \(reqInfo.host)  timeout , will close 5",level: .Warning)
                                client_free_socks()
                                
                            }
                        }
                    }else {
                        if reqInfo.idleTimeing > SFOpt.HTTPVeryTimeout/2.0{
                            if let c = connector {
                                if c.readPending == false {
                                    //SKit.log("\(cIDString) \(reqInfo.host)  resume reading",level: .Warning)
                                    client_socks_recv_initiate()
                                }
                            }
                        }else if reqInfo.idleTimeing > SFOpt.HTTPVeryTimeout{
                            
                            SKit.log("\(cIDString) \(reqInfo.host)  timeout , will close 6",level: .Warning)
                            client_free_socks()
                            
                        }else {
                            
                            
                            
                        }
                    }
                    
                } else {
                    if reqInfo.idleTimeing > SFOpt.HTTPVeryTimeout {
                        SKit.log("\(cIDString) \(reqInfo.host)  timeout , will close recv:\(socks_recv_bufArray.length) send: \(bufArray.count) 7",level: .Warning)
                        if socks_recv_bufArray.count > 0 {
                            //bug here
                            client_socks_recv_handler_done(socks_recv_bufArray.count)
                        } else {
                            client_free_socks()
                        }
                        
                        
                    }
                }
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
            
            SKit.log("\(reqInfo.host) recv memoryWarning  header queue:\(reqHeaderQueue.count) index:\(requestIndex) http recv header buffer :\(recvHeaderData.length)",level: .Warning)
            SKit.log("\(cIDString) \(reqInfo.host)   will close recv:\(socks_recv_bufArray.length) send: \(bufArray.count)",level: .Warning)
            client_free_socks()
        }
        
    }

    func httpArgu() ->Bool{
        guard let _ = reqInfo.reqHeader else {
            //fatalError()
            return false
        }
        
        if !reqInfo.host.isEmpty && reqInfo.port != 0 {
            return true
        }
        return false
    }

    func findProxy(_ r:SFRuleResult,cache:Bool) {
        
        SKit.log("\(cIDString) Rule Result ",items: r.result.proxyName,level: .Debug)
        reqInfo.findProxy(r,cache: cache)
        
        if !reqInfo.waitingRule {
            SKit.log("\(cIDString) recv rule , now exit waiting",items: reqInfo.rule.policy,level: .Warning)
            
            let tim = String(format: cIDString + " rule :%.6f", reqInfo.ruleTiming)
            SKit.log(tim, level: .Info)
            setUpConnector()
        }else {
            SKit.log("\(cIDString) recv rule waiting",level: .Debug)
        }
        
    }
    func setUpConnector(){
        
        var  host  = reqInfo.host
        let x = host.components(separatedBy: ":")
        if x.count == 2 {
            host = x.first!  //IPV6, 目前还不支持
        }
        let port = reqInfo.port
        let message = String.init(format: "%@ %@",self.reqInfo.url, self.reqInfo.rule.policy.description)
        SKit.log(cIDString + " "  + message + " now setUpConnector",level: .Debug)
        
        if reqInfo.rule.policy == .Reject {
            byebyeRequest()
            return
        }else {
            if reqInfo.rule.policy == .Direct {
                //NSLog(" Direct connect to remote \(host) \(port)")
                var  destIP:String = searchCache(host)
                
                
                if destIP.isEmpty {
                    
                    destIP  = reqInfo.host
                }
                
                
                SKit.log("\(cIDString) DIRECT \(reqInfo.host) \(destIP)",level: .Trace)
                
                
                setUpConnector(destIP, port: UInt16(port))
                
            }else {
                //findProxy()
                
                
                setUpConnector(host, port: UInt16(port))
                
            }
        }
        
        //twitter 10 内加载不成功
        connection(10)
    }
    func connection(_ timeout:TimeInterval) {
        
        if reqInfo.rule.policy != .Reject {
            
            
            reqInfo.sTime = Date() as Date
            if  let s = connector {
                s.delegate = self
                if let manager = manager {
                    s.queue = manager.dispatchQueue
                    //s.socketQueue = manager.socketQueue
                    //s.start()
                }else {
                    SKit.log("TCP Manager error", level: .Error)
                    byebyeRequest()
                }
                
            }else {
                byebyeRequest()
            }
            
            
            //NSLog("################# %@ start ", reqInfo.url)
        }
        
        
    }
    func searchCache(_ domain:String) ->String {
        
        //var destIP:String
        //对于微信 这个app 会是ip, 很早已经解析过
        if let h  = reqInfo.reqHeader{
            if !h.ipAddressV4.isEmpty {
                reqInfo.remoteIPaddress = h.ipAddressV4
                return   h.ipAddressV4
            }
        }
        if !reqInfo.remoteIPaddress.isEmpty {
            return  reqInfo.remoteIPaddress
        }
        let type = domain.validateIpAddr()
        switch type {
        case .IPV4:
            return domain
        case .IPV6:
            return domain
        default:
            break
        }
        let newDomain = domain + "." //dns cache have .
        let ips = SFSettingModule.setting.searchDomain(newDomain)
        if !ips.isEmpty{
            reqInfo.remoteIPaddress = ips.first!
            return ips.first!
        }else {
            
            SKit.log("\(cIDString) don't find DNS cache:\(newDomain)", level: .Trace)
        }
        
        return ""
        
        
        
        
    }
    func genPolicy(_ dest:String,useragent:String) ->Bool{
        //根据host 产生policy
        //对于TCP 需要反查hostname,
        //http 需要做dns 解析
        //ip 呢？
        
        reqInfo.ruleStartTime = Date() as Date
        var j:SFRuleResult
        SKit.log("\(cIDString) Find Rule For  DEST:   " ,items:  dest ,level:  .Debug)
        
        if let r = SFTCPConnectionManager.manager.findRuleResult(dest){
            j = r
            reqInfo.rule = r.result
            findProxy(j,cache: false)
            
        }else {
            
            if let ruler  = SFSettingModule.setting.findRuleByString(dest,useragent:useragent) {
                j = ruler
                
                if !j.ipAddr.isEmpty {
                    reqInfo.remoteIPaddress = j.ipAddr
                }
                reqInfo.rule = ruler.result
                findProxy(j,cache: true)
                
            }else {
                if !reqInfo.remoteIPaddress.isEmpty {
                    findIPRule(reqInfo.remoteIPaddress)
                }else {
                    if SFSettingModule.setting.ipRuleEnable {
                        reqInfo.waitingRule = true
                        SKit.log("async send dns  For  DEST:   " ,items: dest ,level:  .Debug)
                        //findIPaddress()
                        
                        findIPaddressSys(reqInfo.host)
                    }else {
                        SKit.log("\(cIDString) ipRuleEnable disable ,use final rule", level: .Debug)
                        reqInfo.waitingRule = true
                        self.findIPRule("")
                        
                    }
                    
                }
                
            }
            
        }
        
        return !reqInfo.waitingRule
        
        
    }
    func findIPAddress2() {
        let q  = DispatchQueue(label:"com.abigt.dns")
        let hostName = self.reqInfo.host
        q.async { [weak self] in
            let host = CFHostCreateWithName(nil,hostName as CFString).takeRetainedValue()
            //NSLog("getIPFromDNS %@", hostName)
            //let d = NSDate()
            var result:String?
            CFHostStartInfoResolution(host, .addresses, nil)
            var success: DarwinBoolean = false
            if let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as NSArray?,
                let theAddress = addresses.firstObject as? NSData {
                var hostname = [CChar](repeating: 0, count: Int(256))
                let p = theAddress as Data
                let value = p.withUnsafeBytes { (ptr: UnsafePointer<sockaddr>)  in
                    return ptr
                }
                if getnameinfo(value, socklen_t(theAddress.length),
                               &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                    result = String(cString:hostname)
                    
                }
            }
            if let s = self {
                if let result = result {
                    let queue = s.manager!.dispatchQueue
                    //s.findIPRule(result)
                    queue.async{
                        s.findIPRule(result)
                    }
                }else {
                    SKit.log("\(s.reqInfo.host) dns query failure",level: .Error)
                    let queue = s.manager!.dispatchQueue
                    //s.findIPRule(result)
                    queue.async{
                        s.findIPRule("")
                    }
                    
                    
                }
            }else {
                SKit.log("weak error",level: .Error)
            }
            
            
        }
        
    }
    func findIPaddressSys(_ name:String) {
        let q  = DispatchQueue(label:"com.abigt.dns",attributes:[])
        
        //let hostName = self.reqInfo.host
        q.async{ [weak self] in
            if let strong = self {
                let remoteHostEnt = gethostbyname2((name as NSString).utf8String, AF_INET)
                
                if remoteHostEnt == nil {
                    strong.findIPAddress2()
                }else {
                    let remoteAddr = UnsafeMutableRawPointer(remoteHostEnt?.pointee.h_addr_list[0])
                    
                    var output = [Int8](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                    inet_ntop(AF_INET, remoteAddr, &output, socklen_t(INET6_ADDRSTRLEN))
                    let addr =  NSString(utf8String: output)! as String
                    
                    if let m = strong.manager {
                        let dq = m.dispatchQueue
                        dq.async(execute: {
                            strong.findIPRule(addr)
                        })
                        
                        
                    }else {
                        SKit.log("dispatch queue error",level: .Error)
                    }
                    
                }
            }else {
                SKit.log("weak error",level: .Error)
            }
            
            
        }
        
        
        
    }
    func findIPRule(_ ip:String) {
        SKit.log("async request dns back \(self.reqInfo.host)",items: ip,level:.Trace)
        let r  = SFSettingModule.setting.findIPRuler(ip)
        
        let result:SFRuleResult = SFRuleResult.init(request:self.reqInfo.host ,r: r)
        result.ipAddr = ip
        result.result.ipAddress = ip
        if reqInfo.remoteIPaddress != ip {
            reqInfo.remoteIPaddress = ip
        }
        
        self.findProxy(result,cache: !ip.isEmpty)
    }
    func configConnector(){
        if httpArgu() {
            var agent:String = ""
            var domainName = reqInfo.host
            if let h = reqInfo.reqHeader {
                agent = h.app
                if !h.ipAddressV4.isEmpty{
                    domainName = h.ipAddressV4
                }
            }
            
            
            if genPolicy(domainName,useragent:agent) {
                if reqInfo.rule.policy == .Reject {
                    byebyeRequest()
                }else {
                    SKit.log("\(cIDString) Not Reject Will Send Req",level: .Debug)
                    //setUpConnector()
                }
                
            }else {
                SKit.log("\(cIDString) \(reqInfo.host) Waiting Rule",level: .Debug)
            }
        }else {
            byebyeRequest()
        }

    }
    func setUpConnector(_ host:String,port:UInt16){
        let q = SFTCPConnectionManager.manager.dispatchQueue
        guard let c = TCPSession.socketFromProxy(reqInfo.proxy, policy: reqInfo.rule.policy, targetHost: host, Port: port, sID: reqInfo.reqID, delegate: self, queue: q) else {
            fatalError("")
        }
        connector = c
    }
    func byebyeRequest(){
        print("byebyeRequest")
    }
    func client_free_socks(){
        print("client_free_socks")
    }
    func client_socks_recv_handler_done(_ len:Int){
        print("client_socks_recv_handler_done")
    }
    func client_socks_send_handler_done(_ len:Int){
        print("client_socks_send_handler_done")
    }
    func sendFakeCONNECTResponse(){
        print("sendFakeCONNECTResponse")
    }
    func client_socks_recv_send_out(){
        print("client_socks_recv_send_out")
    }
    func checkBufferHaveData(_ buffer:Data,data:Data) -> Range<Data.Index>? {
        let r = buffer.range(of: data , options: Data.SearchOptions.init(rawValue: 0), in: Range(0 ..< buffer.count))
        return r
    }
    func forceCloseRemote(){
        print("forceCloseRemote")
    }
}