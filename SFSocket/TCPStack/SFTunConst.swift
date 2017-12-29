//
//  SFTunConst.swift
//  Surf
//
//  Created by yarshure on 16/1/15.
//  Copyright © 2016年 yarshure. All rights reserved.
//

import Foundation
import SwiftyJSON
//extension  JSON{}


//        typedef NS_ENUM(NSInteger, GCDAsyncSocketError) {
//            GCDAsyncSocketNoError = 0,           // Never used
//            GCDAsyncSocketBadConfigError,        // Invalid configuration
//            GCDAsyncSocketBadParamError,         // Invalid parameter was passed
//            GCDAsyncSocketConnectTimeoutError,   // A connect operation timed out
//            GCDAsyncSocketReadTimeoutError,      // A read operation timed out
//            GCDAsyncSocketWriteTimeoutError,     // A write operation timed out
//            GCDAsyncSocketReadMaxedOutError,     // Reached set maxLength without completing
//            GCDAsyncSocketClosedError,           // The remote peer closed the connection
//            GCDAsyncSocketOtherError,            // Description provided in userInfo
//        };



public enum SFSocketStat:Int,CustomStringConvertible {
    case close = 0
    case connecting = 1
    case established = 2
    case closeing = 3
    case closed = 4
    public var description: String {
        switch self {
        case .close: return "CLOSE"
        case .connecting: return "CONNECTING"
        case .established: return "CONNECTED"
        case .closeing: return "CLOSEING"
        case .closed: return "CLOSED"
        }
    }
}

public enum HTTPConnectionState:Int,CustomStringConvertible {
    case httpDefault = 0
    case httpReqHeader = 1
    case httpReqBody = 2
    case httpCONNECTSending = 3
    case httpCONNECTRecvd = 4
    case httpReqSending = 5
    case httpReqSended = 6
    case httpRespHeader = 7
    case httpRespBody = 8
    case httpRespFinished = 9
    case httpRespReading = 10 //长链接,chunked mode
    
    public var description: String {
        switch self {
        case .httpDefault: return "HttpDefault"
        case .httpReqHeader: return "HttpReqHeader"
        case .httpReqBody : return  "HttpReqBody"
        case .httpCONNECTSending: return "HttpCONNECTSending"
        case .httpCONNECTRecvd: return "HttpCONNECTRecvd"
        case .httpReqSending: return "HttpReqSending"
        case .httpReqSended : return "HttpReqSended"
        case .httpRespHeader : return "HttpRespHeader"
        case .httpRespBody : return "HttpRespBody"
        case .httpRespFinished : return "HttpRespFinished"
        case .httpRespReading :return "HttpRespReading"
        }
    }
}
public enum sftcp_state:Int8,CustomStringConvertible {
    case closed      = 0
    case listen      = 1
    case syn_SENT    = 2
    case syn_RCVD    = 3
    case established = 4
    case fin_WAIT_1  = 5
    case fin_WAIT_2  = 6
    case close_WAIT  = 7
    case closing     = 8
    case last_ACK    = 9
    case time_WAIT   = 10
    public var description: String {
        switch self {
        case .closed: return "CLOSED"
        case .listen: return "LISTEN"
        case .syn_SENT: return "SYN_SENT"
        case .syn_RCVD: return "SYN_RCVD"
        case .established: return "ESTABLISHED"
        case .fin_WAIT_1: return "FIN_WAIT_1"
        case .fin_WAIT_2: return "FIN_WAIT_2"
        case .close_WAIT: return "CLOSE_WAIT"
        case .closing: return "CLOSING"
        case .last_ACK: return "LAST_ACK"
        case .time_WAIT: return "TIME_WAIT"
        }
    }
};

