//
//  UpgradeResult.swift
//  NetworkKit
//
//  Created by Isaque da Silva on 1/15/25.
//

import NIOCore
import NIOWebSocket

extension WebSocketHandler {
    enum UpgradeResult {
        case websocket(NIOAsyncChannel<WebSocketFrame, WebSocketFrame>)
        case notUpgraded
    }
}
