//
//  WebSocketError.swift
//  
//
//  Created by Isaque da Silva on 02/07/24.
//

import Foundation

extension WebSocketClient {
    /// An error collection that may occur when execution the WebSocket channel.
    public enum WebSocketError: Error, LocalizedError, Sendable {
        case failedToSendData
        case notUpgraded
        case decodingError
        case noConnection
        case unknownError(Error)
        case dataNotSuported
        
        public var errorDescription: String? {
            switch self {
            case .failedToSendData:
                "Failed to send data in the channel."
            case .decodingError:
                "Failed to decode a data coming from the channel."
            case .noConnection:
                "They are no connections available to handle with this task."
            case .unknownError(let error):
                "An unexpected error occur. Error: \(error.localizedDescription)"
            case .dataNotSuported:
                "An unexpected data type was received."
            case .notUpgraded:
                "The channel was not upgraded correctly."
            }
        }
    }
}
