//
//  BlockCrypt.swift
//  SFSocket
//
//  Created by 孔祥波 on 29/03/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//

import Foundation

class BlockCrypt {
    
    init(type:String,key:Data) {
        switch type {
        case "tea":
            //block, _ = kcp.NewTEABlockCrypt(pass[:16])
            break
        case "xor":
            //block, _ = kcp.NewSimpleXORBlockCrypt(pass)
            break
        case "none":
            //block, _ = kcp.NewNoneBlockCrypt(pass)
            break
        case "aes-128":
            //block, _ = kcp.NewAESBlockCrypt(pass[:16])
            break
        case "aes-192":
            //block, _ = kcp.NewAESBlockCrypt(pass[:24])
            break
        case "blowfish":
            //block, _ = kcp.NewBlowfishBlockCrypt(pass)
            break
        case "twofish":
            //block, _ = kcp.NewTwofishBlockCrypt(pass)
            break
        case "cast5":
            //block, _ = kcp.NewCast5BlockCrypt(pass[:16])
            break
        case "3des":
            //block, _ = kcp.NewTripleDESBlockCrypt(pass[:24])
            break
        case "xtea":
            //block, _ = kcp.NewXTEABlockCrypt(pass[:16])
            break
        case "salsa20":
            //block, _ = kcp.NewSalsa20BlockCrypt(pass)
            break
        default:
            break
            //config.Crypt = "aes"
            //block, _ = kcp.NewAESBlockCrypt(pass)
        }
    }
    func create(pass:Data){
        
    }

}
