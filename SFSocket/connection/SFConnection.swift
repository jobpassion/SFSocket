//
//  SFConnection.swift
//  SFSocket
//
//  Created by 孔祥波 on 23/11/2016.
//  Copyright © 2016 Kong XiangBo. All rights reserved.
//

import Foundation
//For TCP Connection
open class SFConnection :RawSocketDelegate{
    public /**
     The socket did disconnect.
     
     This should only be called once in the entire lifetime of a socket. After this is called, the delegate will not receive any other events from that socket and the socket should be released.
     
     - parameter socket: The socket which did disconnect.
     */
    func didDisconnect(_ socket: RawSocketProtocol, error: Error?) {
        
    }

    
    
    
    open func didDisconnect(_ socket: RawSocketProtocol){
        
    }
    open func didReadData(_ data: Data, withTag: Int, from: RawSocketProtocol){
        
    }
    
    open func didWriteData(_ data: Data?, withTag: Int, from: RawSocketProtocol){
        
    }
    
    open func didConnect(_ socket: RawSocketProtocol){
        
    }
}
