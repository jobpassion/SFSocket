//
//  SFHTTP.swift
//  Surf
//
//  Created by yarshure on 16/3/7.
//  Copyright © 2016年 yarshure. All rights reserved.
//

import Foundation
import AxLogger

class SFHTTPRequest: SFConnection{
    
    
    var headerData:Data = Data()
    
    //var lwipRow:NSMutableData = NSMutableData()
    
    var httpStat:HTTPConnectionState = .httpDefault
    

    


    override internal init(tcp:SFPcb, host:UInt32,port:UInt16, m:SFTCPConnectionManager){
        super.init(tcp: tcp,host: host,port: port,m: m)
        
        self.reqInfo.mode  = .HTTP
        reqInfo.lport = info.tun.port
        
       //AxLogger.log("\(cIDString) start at \(reqInfo.sTime)",level: .Debug )
    }
    func processData(_ reason:String){
        
    }
    func checkBufferHaveData(_ buffer:Data,data:Data) -> Range<Data.Index>? {
        let r = buffer.range(of: data , options: Data.SearchOptions.init(rawValue: 0), in: Range(0 ..< buffer.count))
        return r
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
    func configConnector (){
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
                    AxLogger.log("\(cIDString) Not Reject Will Send Req",level: .Debug)
                    //setUpConnector()
                }
                
            }else {
                AxLogger.log("\(cIDString) \(reqInfo.host) Waiting Rule",level: .Debug)
            }
        }else {
           byebyeRequest()
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
            
            AxLogger.log("\(cIDString) don't find DNS cache:\(newDomain)", level: .Trace)
        }
            
        return ""
        
        
        
        
    }
    override func setUpConnector(){
        
        var  host  = reqInfo.host
        let x = host.components(separatedBy: ":")
        if x.count == 2 {
            host = x.first!  //IPV6, 目前还不支持
        }
        let port = reqInfo.port
        let message = String.init(format: "%@ %@",self.reqInfo.url, self.reqInfo.rule.policy.description)
        AxLogger.log(cIDString + " "  + message + " now setUpConnector",level: .Debug)

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
                
                
                AxLogger.log("\(cIDString) DIRECT \(reqInfo.host) \(destIP)",level: .Trace)
                
                
                setUpConnector(destIP, port: UInt16(port))
                
            }else {
                //findProxy()
                
                
                setUpConnector(host, port: UInt16(port))
                
            }
        }
        
        //twitter 10 内加载不成功
        connection(10)
    }
    override func didWriteData(_ data: Data?, withTag: Int, from: TCPSession){
       //AxLogger.log("\(cIDString) didWriteDataWithTag \(_tag) \(tag)",level: .Debug)
        //NSLog("currrent tag: \(tag) == \(_tag)")
        reqInfo.status = .Transferring
        
        //debugLog("\(cIDString) didWriteDataWithTag")
        let x = Int64(withTag)
        reqInfo.activeTime = Date() as Date
        
            //let d = bufArray.removeFirst()
            let len = bufArrayInfo[x]
            client_socks_send_handler_done(len!)
            bufArrayInfo.removeValue(forKey: x)
            reqInfo.updateSendTraffic(len!)
           //AxLogger.log("\(cIDString) tag:\(tag) time:\(reqInfo.transferTiming) packet sended and delete flow:\(reqInfo.traffice.tx):\(reqInfo.traffice.rx)",level: .Debug)
            // 这个地方有问题 https over http ,how to send this?
            
            
        
        
        tag += 1
//        if reqInfo.reqHeader?.Method != .CONNECT {
//            httpStat =  .HttpReqSended
//        }
        
        processData("didWriteData")
    }
    //FB 不走https 代理，够恶心的
    func sendCONNECTResponse(){
        //tel lwip header +\r\n received
        //self.reqInfo.mode = .HTTPS
        //httpStat = .HttpReqBody
        guard let h = reqInfo.reqHeader else {return}
        //AxLogger.log("\(cIDString) tel lwip  CONNECT head \(h.length) received and send fake replay \(SSL_CONNECTION_RESPONSE)",level: .Debug)
        client_socks_send_handler_done(h.length)
        guard  let s = SSL_CONNECTION_RESPONSE.data(using: .utf8, allowLossyConversion: false) else {
                return
        }
        if let header  = SFHTTPResponseHeader.init(data: s) {
            reqInfo.respHeader = header
        }else {
            AxLogger.log(" CONNECT Response parser error",level: .Error)
        }
        let newData = s
        socks_recv_bufArray.append(newData)
        
        client_socks_recv_handler_done(s.count)
        
    }
    func sendFakeCONNECTResponse() ->Bool{
        //链接建立
        AxLogger.log("\(cIDString) send sendFakeCONNECTResponse",level: .Debug)
        var need = false
        if reqInfo.mode == .HTTPS  {
            need = true
        }else {
            if let head = reqInfo.reqHeader , head.method == .CONNECT {
                reqInfo.mode = .HTTPS
                need = true
            }
        }
        
        if need {
            sendCONNECTResponse()
        }
        return need
    }

}
