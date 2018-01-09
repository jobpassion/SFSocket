//
//  NEPacketTunnelProvider+Extension.swift
//  SFSocket
//
//  Created by 孔祥波 on 07/04/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//

import Foundation
import NetworkExtension
import AxLogger
import XRuler
extension NEPacketTunnelProvider{
    public func logStopReason( reason: NEProviderStopReason){
        var reasonString:String
        switch reason {
            /*! @const NEProviderStopReasonNone No specific reason. */
        case .none:
            reasonString = "No specific "
        case .userInitiated:
            reasonString = "user stopped"
        case .providerFailed:
            reasonString = "The provider failed"
            /*! @const NEProviderStopReasonNoNetworkAvailable There is no network connectivity. */
        case .noNetworkAvailable:
            reasonString = " no network"/*! @const NEProviderStopReasonUnrecoverableNetworkChange The device attached to a new network. */
        case .unrecoverableNetworkChange:
            reasonString = "device attached to a new network"/*! @const NEProviderStopReasonProviderDisabled The provider was disabled. */
        case .providerDisabled:
            reasonString = "provider was disabled"
            /*! @const NEProviderStopReasonAuthenticationCanceled The authentication process was cancelled. */
        case .authenticationCanceled:
            reasonString = "The authentication process was cancelled"
            /*! @const NEProviderStopReasonConfigurationFailed The provider could not be configured. */
        case .configurationFailed:
            reasonString = "The provider could not be configured."
            /*! @const NEProviderStopReasonIdleTimeout The provider was idle for too long. */
        case .idleTimeout:
            reasonString = "The provider was idle for too long"
            /*! @const NEProviderStopReasonConfigurationDisabled The associated configuration was disabled. */
        case .configurationDisabled:
            reasonString = "The associated configuration was disabled."
            /*! @const NEProviderStopReasonConfigurationRemoved The associated configuration was deleted. */
        case .configurationRemoved:
            reasonString = "The associated configuration was deleted."
            /*! @const NEProviderStopReasonSuperceded A high-priority configuration was started. */
        case .superceded:
            reasonString = "A high-priority configuration was started."
            /*! @const NEProviderStopReasonUserLogout The user logged out. */
        case .userLogout:
            reasonString = "The user logged out."
            /*! @const NEProviderStopReasonUserSwitch The active user changed. */
        case .userSwitch:
            reasonString = "The active user changed."
            /*! @const NEProviderStopReasonConnectionFailed Failed to establish connection. */
        case .connectionFailed:
            reasonString = "Failed to establish connection."
        }
        alertMessage(message: "stoping: \(reasonString)",reason: reason)
        //#displayMessage
        
    }
    public func alertMessage(message:String,reason:NEProviderStopReason){
        if #available(iOSApplicationExtension 10.0, *) {
            //VPN can alert
            if reason != .userInitiated {
                if #available(OSXApplicationExtension 10.12, *) {
                    displayMessage(message, completionHandler: { (fin) in
                        
                    })
                } else {
                    SKit.log("don't support displayMessage",level:.Info)
                }
            }
            
        }
        SKit.log(message,level:.Info)
    }
    public func generateOutputBlock() -> ([Data], [NSNumber]) -> () {
        return { [weak self] packets, versions in
            if let strong = self {
                strong.packetFlow.writePackets(packets as [Data], withProtocols: versions)
            }
            
        }
    }
  
    
    
    /// Write packets and associated protocols to the UTUN interface.
    public func processPackets(packets: [Data], protocols: [NSNumber]) {
       //process todo
        
        SKit.packetProcessor?.sendPackets(packets, protocols: protocols)
    }
    public func startHandlingPackets() {
        
        
        packetFlow.readPackets { [unowned self ] inPackets, inProtocols in
            self.processPackets(packets: inPackets, protocols: inProtocols)
        }
        
    }
 
}

extension NEPacketTunnelProvider:PacketProcessorProtocol {
    public func writeDatagram(packet: Data, proto: Int32) {
        if packet.count > 0 {
            
            
            //UDPManager.shared.serverDidQuery(targetTunnel, data: data, close: close)
            var packets = [Data]()
            var protocols = [NSNumber]()
            packets.append(packet)
            protocols.append(NSNumber(value: AF_INET))
            
            packetFlow.writePackets(packets, withProtocols: protocols)
            
        }
    }
    
    public func writeDatagrams(packet: [Data], proto: [NSNumber]) {
        packetFlow.writePackets(packet, withProtocols: proto)
    }
    
    
   
    public func didProcess() {
        //after process packets ,call this func
        self.startHandlingPackets()
    }

 
}
extension NEPacketTunnelProvider{
    public func reportTask() {
        let report = SFVPNStatistics.shared
        report.lastTraffice.tx = report.currentTraffice.tx
        report.lastTraffice.rx = report.currentTraffice.rx
        var snapShot = SFTraffic()
        snapShot.tx = report.currentTraffice.tx
        snapShot.rx = report.currentTraffice.rx
        report.netflow.update(snapShot, type: .total)
        
        report.currentTraffice.tx = 0
        report.currentTraffice.rx = 0
        report.totalTraffice.addRx(x: Int(report.lastTraffice.rx))
        report.totalTraffice.addTx(x: Int(report.lastTraffice.tx))
        
        report.updateMax()
    }
}
