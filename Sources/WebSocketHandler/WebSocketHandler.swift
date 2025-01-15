//
//  File.swift
//  NetworkKit
//
//  Created by Isaque da Silva on 1/14/25.
//

import Common
import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOWebSocket
import NIOFoundationCompat

public struct WebSocketHandler<ReceivedMessage: Decodable>: Sendable {
    /// A representation path to find the desired path to open the connection
    private let endpoint: Endpoint
    
    /// A default event loop group to make active the WebSocket connection.
    private let eventLoopGroup: MultiThreadedEventLoopGroup
    
    /// A default WebSocket Upgrader for this aplication.
    private var wsUpgrader: EventLoopFuture<UpgradeResult>?
    
    private var outboundWriter: NIOAsyncChannelOutboundWriter<WebSocketFrame>?
}
