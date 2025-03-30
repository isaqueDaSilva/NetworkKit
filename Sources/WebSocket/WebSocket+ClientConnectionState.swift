//
//  WSConnectionState.swift
//  NetworkKit
//
//  Created by Isaque da Silva on 3/12/25.
//

extension WebSocketClient {
    /// Representation of the current state of a WebSocket channel.
    public enum ConnectionState: String, Sendable {
        case disconnected = "Disconnected"
        case connecting = "Connecting"
        case connected = "Connected"
    }
}
