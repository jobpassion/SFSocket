//
//  HTTPProxyConnector.swift
//  SimpleTunnel
//
//  Created by yarshure on 15/11/11.
//  Copyright © 2015年 Apple Inc. All rights reserved.
//

import Foundation
import AxLogger
//public enum SFConnectionMode:String {
//    case HTTP = "HTTP"
//    case HTTPS = "HTTPS"
//    case TCP = "TCP"
//    //case CONNECT = "CONNECT"
//    public var description: String {
//        switch self {
//        case .HTTP: return "HTTP"
//        case .HTTPS: return "HTTPS"
//        case .TCP: return "TCP"
//            //case CONNECT: return "CONNECT"
//        }
//    }
//    
//}
public  class HTTPProxyConnector:ProxyConnector {
    
    var connectionMode:SFConnectionMode = .HTTP
    public var reqHeader:SFHTTPRequestHeader?
    public var respHeader:SFHTTPResponseHeader?
    var httpConnected:Bool = false
    var headerData:Data = Data()
    static let ReadTag:Int = -2000
    // https support current don't support
    deinit {
        //reqHeader = nil
        //respHeader = nil
        SKit.log(cIDString + "deinit", level: .Debug)
    }
    func sendReq() {
        if let req = reqHeader  {
            if let data = req.buildCONNECTHead(self.proxy) {
                SKit.log(cIDString + " sending CONNECTHead",items: data,req.method,level: .Debug)
                self.writeData(data, withTag: HTTPProxyConnector.ReadTag)
            }else {
               SKit.log(cIDString + " buildCONNECTHead error",level: .Error)
            }
        }else {
            //sleep(1)
            //sendReq()
           SKit.log("\(cIDString)  not reqHeader  error",level: .Error)
        }

    }
    func recvHeaderData(data:Data) ->Int{
        // only use display response status,recent request feature need
        if let r = data.range(of:hData, options: Data.SearchOptions.init(rawValue: 0)){
        
            // body found
            if headerData.count == 0 {
                headerData = data
            }else {
                headerData.append( data)
            }
            //headerData.append( data.subdata(in: r))
            
            respHeader = SFHTTPResponseHeader(data: headerData)
            if let r = respHeader, r.sCode != 200 {
                SKit.log("HTTP PRoxy CONNECT status",items:r.sCode,level: .Error)
                //有bug
                
                //let e = NSError(domain:errDomain , code: 10,userInfo:["reason":"http auth failure!!!"])
                SKit.log("socketDidCloseReadStream",items: data,level:.Error)
                self.forceDisconnect()
                //sendReq()
                //NSLog("CONNECT status\(r.sCode) ")
            }
        
           
            
            return r.upperBound // https need delete CONNECT respond
        }else {
            headerData.append(data)
            
        }
        return 0
    }
 
    override func readCallback(data: Data?, tag: Int) {
        
        guard let data = data else {
            SKit.log("\(cIDString) read nil", level: .Debug)
            return
        }
        queueCall {
          
            //SKit.log("read data \(data)", level: .Debug)
            if self.httpConnected == false {
                if self.respHeader == nil {
                    let len = self.recvHeaderData(data: data)
                    
                    if len == 0{
                        SKit.log("http  don't found resp header",level: .Warning)
                    }else {
                        //找到resp header
                        self.httpConnected = true
                        if let d = self.delegate {
                            d.didConnect(self)
                        }
                        if len < data.count {
                            let dataX = data.subdata(in: Range(len ..< data.count ))
                            //delegate?.connector(self, didReadData: dataX, withTag: 0)
                            autoreleasepool(invoking: {
                                self.delegate?.didReadData( dataX, withTag: tag, from: self)
                            })
                            
                            //SKit.log("\(cIDString) CONNECT response data\(data)",level: .Error)
                        }
                    }
                }

                //self.readDataWithTag(-1)
            }else {
                autoreleasepool(invoking: {
                    self.delegate?.didReadData( data, withTag: tag, from: self)
                })
                
            }
            
        }
    }
    

    override public func socketConnectd() {
       
        if httpConnected == false {
            self.sendReq()
        }else {
            self.delegate?.didConnect( self)
        }
    }

    public override func sendData(data: Data, withTag tag: Int) {
        if writePending {
            SKit.log("Socket-\(cID)  writePending error", level: .Debug)
            return
        }
        writePending = true
        if isConnected == false {
            SKit.log("isConnected error", level: .Error)
            return
        }
        self.connection!.write(data) {[weak self] error in
            guard let strong = self else  {return}
            strong.writePending = false
            
            guard error == nil else {
                SKit.log("NWTCPSocket got an error when writing data: ",items: error!.localizedDescription,level: .Debug)
                strong.forceDisconnect()
                return
            }
            
            strong.queueCall {
                if strong.httpConnected == false {
                    strong.readDataWithTag(HTTPProxyConnector.ReadTag)
                }else {
                    strong.queueCall { autoreleasepool {
                        strong.delegate?.didWriteData(data, withTag: tag, from: strong)
                    }}
                }
                
            }
            strong.checkStatus()
        }
    }
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
      
        guard keyPath == "state" else {
            return
        }
        //crash
       
        
        if object == nil {
            SKit.log("\(cIDString) connection lost", level: .Error)
            disconnect()
            return
        }
        if let error = connection?.error {
            SKit.log("Socket-\(cIDString) state:",items:error.localizedDescription, level: .Debug)
        }
        
        switch connection!.state {
        case .connected:
            queueCall {[weak self] in
                if let strong = self {
                    strong.socketConnectd()
                }
                
            }
        case .disconnected:
            cancel()
        case .cancelled:
            queueCall {
                if let delegate = self.delegate{
                    delegate.didDisconnect(self, error: nil)
                }
                
                //self.delegate = nil
            }
        default:
            break
            //        case .Connecting:
            //            stateString = "Connecting"
            //        case .Waiting:
            //            stateString =  "Waiting"
            //        case .Invalid:
            //            stateString = "Invalid"
            
        }
        //        if let  x = connection.endpoint as! NWHostEndpoint {
        //
        //        }
        if let error = connection!.error {
            SKit.log("\(cIDString) ",items: error.localizedDescription, level: .Error)
        }
        SKit.log("\(cIDString) stat:",items: connection!.state.description, level: .Debug)
    }

    public static func connectorWithSelectorPolicy(targetHostname hostname:String, targetPort port:UInt16,p:SFProxy,delegate: RawSocketDelegate, queue: DispatchQueue) ->HTTPProxyConnector{
        let c:HTTPProxyConnector = HTTPProxyConnector(p: p)
        //c.manager = man
        //c.cIDFunc()
        c.delegate = delegate
        c.queue = queue
        c.targetHost = hostname
        c.targetPort = port
        
        c.start()
        return c
    }
}
