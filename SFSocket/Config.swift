//
//  Config.swift
//  SFSocket
//
//  Created by 孔祥波 on 29/03/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//

import Foundation

//default tun config
struct TunConfig {
    let SALT:String = "kcp-go"
    var LocalAddr:String = " localaddr"
    var RemoteAddr   :String = "remoteaddr"
    var Key          :String = "key"
    var Crypt        :String = "aes"
    var Mode         :String = "fast"
    var Conn         :Int = 1 // 0//"conn"
    var AutoExpire   :Int = 0 // "autoexpire"
    var ScavengeTTL  :Int = 600 // "scavengettl"
    var MTU          :Int = 1350 // "mtu"
    var SndWnd       :Int = 128 // "sndwnd"
    var RcvWnd       :Int = 512 // "rcvwnd"
    var DataShard    :Int = 10 // "datashard"
    var ParityShard  :Int = 3 // "parityshard"
    var DSCP         :Int = 0 // "dscp"
    //todo fix
    var NoComp       : Bool =  false //"nocomp"
    var AckNodelay   : Bool = false //"acknodelay"
    var NoDelay      :Int = 0 // "nodelay"
    var Interval     :Int = 50 // ":Interval"
    var Resend       :Int = 0 // "resend"
    var NoCongestion :Int = 0 // "nc"
    var SockBuf      :Int = 4194304 // "sockbuf"
    var KeepAlive    :Int = 10 // "keepalive"
    var Log          :String = "log"
    var SnmpLog      :String = "snmplog"
    var SnmpPeriod   :Int = 60 // "snmpperiod"
    var pass:String = ""
    mutating func setMode() {
        switch Mode {
        case "normal":
            NoDelay = 0
            Interval = 40
            Resend = 2
            NoCongestion = 1
        case "fast":
            NoDelay = 0
            Interval = 30
            Resend = 2
            NoCongestion = 1
        case "fast2":
            NoDelay = 1
            Interval = 20
            Resend = 2
            NoCongestion = 1
        case "fast3":
            NoDelay = 1
            Interval = 10
            Resend = 2
            NoCongestion = 1
        
            
        default:
            break
        }
    }
    //MARK: - fixme
    mutating func pkbdf2Key(pass:String) ->Data{
        
        //pass := pbkdf2.Key([]byte(config.Key), []byte(SALT), 4096, 32, sha1.New)
        return Data()
    }
}
