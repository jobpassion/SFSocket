//
//  extension.swift
//  Mocha
//
//  Created by yarshure on 2017/12/11.
//  Copyright © 2017年 yarshure. All rights reserved.
//

import Foundation
import NetworkExtension
import AxLogger
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
                    // Fallback on earlier versions
                }
            }
            
        }
        AxLogger.log(message,level:.Info)
    }
}
