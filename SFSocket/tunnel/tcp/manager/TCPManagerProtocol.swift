//
//  TCPManagerProtocol.swift
//  SFSocket
//
//  Created by 孔祥波 on 06/04/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//

import Foundation

public protocol  TCPManagerProtocol: class{
    func writeDatagram(packets : Data,proto:Int32)
}
