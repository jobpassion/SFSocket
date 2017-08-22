//
//  RowTCPSocket.swift
//  SFSocket
//
//  Created by yarshure on 2017/8/22.
//  Copyright © 2017年 Kong XiangBo. All rights reserved.
//

import Foundation

class RowTCPSocket: NSObject,SocketProtocol,RawSocketDelegate {
    

    

    /// The current connection status of the socket.
    var status: SocketStatus = .invalid

    
    func didDisconnect(_ socket: RawSocketProtocol,  error:Error?){
        
    }
    func didReadData(_ data: Data, withTag: Int, from: RawSocketProtocol){
        
    }
    func didWriteData(_ data: Data?, withTag: Int, from: RawSocketProtocol){
        
    }
    
   
    func didConnect(_ socket: RawSocketProtocol){
        _status = .established
    }
    open var socket: RawSocketProtocol!
    
    
    
    /// The delegate instance.
    var delegate: SocketDelegate?
    
    /// Every delegate method should be called on this dispatch queue. And every method call and variable access will be called on this queue.
    var queue: DispatchQueue!
    
    /// The current connection status of the socket.
    var _status: SocketStatus = .invalid
    
    internal var _cancelled = false
    public var isCancelled: Bool {
        return _cancelled
    }
    
    override init() {
        super.init()
        self.socket = RawSocketFactory.getRawSocket()
    }
    func openSocketWith(remote:String, port:UInt16,enableTLS:Bool = false,setting:[NSObject : AnyObject]? = nil){
        guard  !isCancelled else {
            return
        }
        do {
            try socket?.connectTo(remote, port: port, enableTLS: enableTLS, tlsSettings: setting)
        }catch let e {
            print("\(e.localizedDescription)")
            return
        }
        socket.delegate = self
        _status = .connecting
    }
    /// If the socket is disconnected.
    var isDisconnected: Bool = true
    
    
    
    /**
     Read data from the socket.
     
     - parameter tag: The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    func readDataWithTag(_ tag: Int){
     
        guard !isCancelled else {
            return
        }
        socket?.readDataWithTag(tag)
    }
    
    /**
     Send data to remote.
     
     - parameter data: Data to send.
     - parameter tag:  The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last write is finished, i.e., `delegate?.didWriteData()` is called.
     */
    func writeData(_ data: Data, withTag tag: Int){
        guard !isCancelled else {
            return
        }
        socket.writeData(data, withTag: tag)
    }
    

    
    /**
     Disconnect the socket elegantly.
     */
    func disconnect(becauseOf error: Error?){
        
    }
    
    /**
     Disconnect the socket immediately.
     */
    func forceDisconnect(becauseOf error: Error?){
        
    }
}
