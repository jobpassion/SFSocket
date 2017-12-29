//
//  TUNConnection.swift
//  Surf
//
//  Created by 孔祥波 on 16/2/6.
//  Copyright © 2016年 yarshure. All rights reserved.
//

import Foundation
import Xcon
import XProxy
class TUNConnection: Connection{
    override func didDisconnect(_ socket: Xcon, error: Error?) {
        
    }
    
    override func didReadData(_ data: Data, withTag: Int, from: Xcon) {
        
    }
    
    override func didWriteData(_ data: Data?, withTag: Int, from: Xcon) {
        
    }
    
    override func didConnect(_ socket: Xcon) {
        
    }
    
   

    
 
    
    override func memoryWarning(_ level:DispatchSource.MemoryPressureEvent){
        
    }
}
