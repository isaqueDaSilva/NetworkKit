//
//  WebSocketSwiftNIOConfiguration.swift
//  NetworkKit
//
//  Created by Isaque da Silva on 3/29/25.
//

import NIOHTTP1
import NetworkHandler

extension WebSocketSwiftNIOClient {
    public struct WebSocketSwiftNIOConfiguration: Sendable {
        let host: String
        let uri: String
        let port: Int
        let headers: HTTPHeaders
        let pingTryToReconnectCountLimit: Int
        
        public init(
            host: String,
            uri: String,
            port: Int,
            headers: HTTPHeaders,
            pingTryToReconnectCountLimit: Int = 3
        ) {
            self.host = host
            self.uri = uri
            self.port = port
            self.headers = headers
            self.pingTryToReconnectCountLimit = pingTryToReconnectCountLimit
        }
    }
}
