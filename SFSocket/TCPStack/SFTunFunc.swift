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

func getIFAddresses() -> [NetInfo] {
    var addresses = [NetInfo]()
    //let d0 = NSDate()
    // Get list of all interfaces on the local machine:
    var ifaddr : UnsafeMutablePointer<ifaddrs>? = nil
    if getifaddrs(&ifaddr) == 0 {
        
        // For each interface ...
        var ptr = ifaddr
        while( ptr != nil) {
            
            let flags = Int32((ptr?.pointee.ifa_flags)!)
            var addr = ptr?.pointee.ifa_addr.pointee
            
            // Check for running IPv4, IPv6 interfaces. Skip the loopback interface.
            if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                if addr?.sa_family == UInt8(AF_INET) || addr?.sa_family == UInt8(AF_INET6) {
                    
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(256))//NI_MAXHOST
                    if (getnameinfo(&addr!, socklen_t((addr?.sa_len)!), &hostname, socklen_t(hostname.count),
                        nil, socklen_t(0), NI_NUMERICHOST) == 0) {
                        if let address = String.init(cString: hostname, encoding: .utf8) {
                            
                            
                            let name = ptr?.pointee.ifa_name
                            let ifname = String.init(cString: name!, encoding: .utf8)
                            
                            //                                var x = NSMutableData.init(length: Int(strlen(name)))
                            //                                let p = UnsafeMutablePointer<Void>.init((x?.bytes)!)
                            //                                memcpy(p, name, Int(strlen(name)))
                            //print(ifname)
                            var net = ptr?.pointee.ifa_netmask.pointee
                            var netmaskName = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                            getnameinfo(&net!, socklen_t((net?.sa_len)!), &netmaskName, socklen_t(netmaskName.count),
                                        nil, socklen_t(0), NI_NUMERICHOST)
                            if let netmask = String.init(cString: netmaskName, encoding: .utf8) {
                                if address.characters.count > 15 {
                                    let net = NetInfo(ip: "2001:470:4a34:ee00:d80a:882c:100:0", netmask: netmask,ifName:ifname!)
                                    addresses.append(net)
                                }else {
                                    let net = NetInfo(ip: address, netmask: netmask,ifName:ifname!)
                                    addresses.append(net)
                                }
                                
                                //addresses[ifname!] = address
                            }
                        }
                    }
                }
            }
            ptr = ptr?.pointee.ifa_next
        }
        freeifaddrs(ifaddr)
    }
    //let d1 = NSDate()
    //print("\(d1.timeIntervalSinceDate(d0))")
    return addresses
}
