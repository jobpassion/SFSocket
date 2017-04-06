//
//  SFTunFunc.swift
//  Surf
//
//  Created by yarshure on 16/3/16.
//  Copyright © 2016年 yarshure. All rights reserved.
//

import Foundation
import Darwin
struct NetInfo {
    // IP Address
    let ip: String
    
    // Netmask Address
    let netmask: String
    let ifName:String
    // CIDR: Classless Inter-Domain Routing
    var cidr: Int {
        var cidr = 0
        for number in binaryRepresentation(netmask) {
            let numberOfOnes = number.components(separatedBy: "1").count - 1
            cidr += numberOfOnes
        }
        return cidr
    }
    
    // Network Address
    var network: String {
        return bitwise(&, net1: ip, net2: netmask)
    }
    
    // Broadcast Address
    var broadcast: String {
        let inverted_netmask = bitwise(~, net1: netmask)
        let broadcast = bitwise(|, net1: network, net2: inverted_netmask)
        return broadcast
    }
    
    
    fileprivate func binaryRepresentation(_ s: String) -> [String] {
        var result: [String] = []
        for numbers in (s.characters.split {$0 == "."}) {
            if let intNumber = Int(String(numbers)) {
                if let binary = Int(String(intNumber, radix: 2)) {
                    result.append(NSString(format: "%08d", binary) as String)
                }
            }
        }
        return result
    }
    
    fileprivate func bitwise(_ op: (UInt8,UInt8) -> UInt8, net1: String, net2: String) -> String {
        let net1numbers = toInts(net1)
        let net2numbers = toInts(net2)
        var result = ""
        for i in 0..<net1numbers.count {
            result += "\(op(net1numbers[i],net2numbers[i]))"
            if i < (net1numbers.count-1) {
                result += "."
            }
        }
        return result
    }
    
    fileprivate func bitwise(_ op: (UInt8) -> UInt8, net1: String) -> String {
        let net1numbers = toInts(net1)
        var result = ""
        for i in 0..<net1numbers.count {
            result += "\(op(net1numbers[i]))"
            if i < (net1numbers.count-1) {
                result += "."
            }
        }
        return result
    }
    
    fileprivate func toInts(_ networkString: String) -> [UInt8] {
        let x = networkString.characters.split(separator: ".", maxSplits: 0, omittingEmptySubsequences: false)
        if x.count == 4 {
            return (networkString.characters.split {$0 == "."}).map{UInt8(String($0))!}
        }else {
            //IPV6
            //return (networkString.characters.split {$0 == ":"}).map{UInt8(String($0))!}
            //let a = "2001:2::aab1:d8c0:844f:100:0"
            let xx = networkString.components(separatedBy: ":")
            //let x = a.characters.split(":")
            
            
            var result:[UInt8] = []
            for item in xx {
                let count = item.characters.count
                let bits = 4 - count
                let string = String.init(repeating: "0", count: bits)
                //print(String(format: "%04s",item))
                let dest = string + String(item)
                for yy in dest.characters{
                    let value = UInt8(strtoul(String(yy), nil, 16))
                    result.append(value)
                }
            }
            return result
        }
        
    }
}


