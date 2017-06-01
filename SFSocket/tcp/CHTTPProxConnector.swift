//
//  CHTTPProxConnector.swift
//  SFSocket
//
//  Created by 孔祥波 on 27/03/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//

import Foundation
import AxLogger
class CHTTPProxConnector: HTTPProxyConnector {
    var adapter:Adapter?
    public static func create(targetHostname hostname:String, targetPort port:UInt16,p:SFProxy,adapter:Adapter,delegate: RawSocketDelegate, queue: DispatchQueue) ->CHTTPProxConnector{
        let c:CHTTPProxConnector = CHTTPProxConnector(p: p)
        c.delegate = delegate
        c.queue = queue
        //c.cIDFunc()
        c.targetHost = hostname
        c.targetPort = port
        c.adapter = adapter
        c.start()
        return c
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
                                guard let  adapter = self.adapter else { return  }
                                let newdata = try! adapter.recv(dataX)
                                self.delegate?.didReadData( newdata.1, withTag: tag, from: self)
                            })
                            
                            //SKit.log("\(cIDString) CONNECT response data\(data)",level: .Error)
                        }
                    }
                }
                
                //self.readDataWithTag(-1)
            }else {
                autoreleasepool(invoking: {
                    guard let  adapter = self.adapter else { return  }
                    let newdata = try! adapter.recv(data)
                    self.delegate?.didReadData( newdata.1, withTag: tag, from: self)
                })
                
            }
            
        }
    }
    
    public override func sendData(data: Data, withTag tag: Int) {
        // filter http protocol connect dat
        if tag == HTTPProxyConnector.ReadTag {
            super.sendData(data: data, withTag: tag)
            return
        }
        guard let  adapter = adapter else { return  }
        let newdata = adapter.send(data)
        super.sendData(data: newdata , withTag: tag)
    }
}
