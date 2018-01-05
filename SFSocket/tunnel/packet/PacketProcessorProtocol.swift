//
//  PacketProcessorProtocol.swift
//  SFSocket
//
//  Created by yarshure on 2018/1/4.
//  Copyright © 2018年 Kong XiangBo. All rights reserved.
//

import Foundation

public protocol  PacketProcessorProtocol :class {
    func writeDatagrams(packet: Data, proto: Int32)
    func didProcess()
}


