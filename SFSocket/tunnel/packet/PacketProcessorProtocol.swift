//
//  PacketProcessorProtocol.swift
//  SFSocket
//
//  Created by yarshure on 2018/1/4.
//  Copyright © 2018年 Kong XiangBo. All rights reserved.
//

import Foundation

public protocol  PacketProcessorProtocol :class {
    //write data to socket/tun
    func writeDatagram(packet: Data, proto: Int32)
    func writeDatagrams(packet: [Data], proto: [NSNumber])
    //PacketProcessor process finish will call this funcation
    func didProcess()
}


