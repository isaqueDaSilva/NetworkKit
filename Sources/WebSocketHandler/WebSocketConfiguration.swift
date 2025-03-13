//
//  WebSocketConfiguration.swift
//  NetworkKit
//
//  Created by Isaque da Silva on 3/12/25.
//

import struct Foundation.TimeInterval
import NetworkHandler

/// A representation data that enables the configuration process for ``WebSocketClient`` type.
public struct WebSocketConfiguration {
    let endpoint: Endpoint
    let timeInterval: TimeInterval
    let pingTryToReconnectCountLimit: Int
    
    public init(
        endpoint: Endpoint,
        timeInterval: TimeInterval = 20,
        pingTryToReconnectCountLimit: Int = 3
    ) {
        self.endpoint = endpoint
        self.timeInterval = timeInterval
        self.pingTryToReconnectCountLimit = pingTryToReconnectCountLimit
    }
}
