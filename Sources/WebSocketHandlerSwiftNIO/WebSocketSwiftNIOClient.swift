//
//  File.swift
//  NetworkKit
//
//  Created by Isaque da Silva on 3/29/25.
//

@preconcurrency import Combine
import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOWebSocket
import NIOFoundationCompat
import os.log

/// An object that handle with the WebSocket channel on client side.
public struct WebSocketSwiftNIOClient<ReceiveMessage: Decodable>: Sendable {
    private let logger = Logger(
        subsystem: "com.isaqueDaSilva.WebSocketSwiftNIOClient",
        category: "WebSocketClient"
    )
    
    private let configuration: WebSocketSwiftNIOConfiguration
    private let eventLoopGroup: MultiThreadedEventLoopGroup
    private var wsUpgrader: EventLoopFuture<UpgradeResult>?
    private var outboundWriter: NIOAsyncChannelOutboundWriter<WebSocketFrame>?
    public let messageReceivedSubject: PassthroughSubject<ReceiveMessage, WebSocketError>
    
    /// Starts the WebSocket channel
    public mutating func start() async throws {
        self.wsUpgrader = try await getUpgraderResult()
        
        self.logger.info("The channel was upgraded with success.")
        
        try await self.upgradeChannel()
    }
    
    /// Establish the WebSoclet channel connection
    /// - Returns: Returns a `EventLoopFuture` for handle with the WebSocket channel
    private func getUpgraderResult() async throws -> EventLoopFuture<UpgradeResult> {
        let upgradeResult: EventLoopFuture<UpgradeResult> = try await ClientBootstrap(group: eventLoopGroup)
            .connect(
                host: self.configuration.host,
                port: self.configuration.port
            ) { channel in
                channel.eventLoop.makeCompletedFuture {
                    let upgrader = NIOTypedWebSocketClientUpgrader<UpgradeResult> { (channel, _) in
                        channel.eventLoop.makeCompletedFuture {
                            let asyncChannel = try NIOAsyncChannel<WebSocketFrame, WebSocketFrame>(
                                wrappingChannelSynchronously: channel
                            )
                            return UpgradeResult.websocket(asyncChannel)
                        }
                    }
                    
                    let requestHead = HTTPRequestHead(
                        version: .http1_1,
                        method: .GET,
                        uri: self.configuration.uri,
                        headers: self.configuration.headers
                    )
                    
                    let clientUpgradeConfig = NIOTypedHTTPClientUpgradeConfiguration(
                        upgradeRequestHead: requestHead,
                        upgraders: [upgrader]
                    ) { channel in
                        channel.eventLoop.makeCompletedFuture {
                            return UpgradeResult.notUpgraded
                        }
                    }
                    
                    let negotiationResultFeature = try channel.pipeline.syncOperations.configureUpgradableHTTPClientPipeline(
                        configuration: .init(upgradeConfiguration: clientUpgradeConfig)
                    )
                    
                    return negotiationResultFeature
                }
            }
        
        self.logger.info("Channel upgrade was getted with success.")
        
        return upgradeResult
    }
    
    /// Handles with the upgrade result.
    private mutating func upgradeChannel() async throws {
        guard let wsUpgrader else {
            return try await disconnect()
        }
        
        switch try await wsUpgrader.get() {
        case .websocket(let wsChannel):
            logger.info("Handling websocket connection...")
            try await handleWebsocketChannel(with: wsChannel)
            try await disconnect()
            logger.info("Done handling websocket connection.")
        case .notUpgraded:
            logger.info("Upgrade declined.")
        }
    }
    
    /// Starts the WebSocket channel and observers the all messages that coming when the channel is alive.
    /// - Parameter channel: The actual WebSocket channel.
    private mutating func handleWebsocketChannel(
        with channel: NIOAsyncChannel<WebSocketFrame, WebSocketFrame>
    ) async throws {
        // Executes the channel.
        try await channel.executeThenClose { inbound, outbound in
            self.outboundWriter = outbound
            
            try await self.sendPing()
            
            // Creates a stream for receive
            // the all data that coming
            // from the WebSocket channel.
            for try await frame in inbound {
                switch frame.opcode {
                case .binary:
                    self.onReceive(frame.data)
                case .pong:
                    logger.info("Connection alive with: \(String(buffer: frame.data))")
                case .connectionClose:
                    try await disconnect()
                default:
                    logger.error("Message received isn't valid")
                    try await self.disconnect()
                    break
                }
            }
        }
    }
    
    /// Handles with the messages that received from the channel.
    /// - Parameter buffer: The buffer that stores the binary data representation for the message.
    private func onReceive(_ buffer: ByteBuffer) {
        guard let message = try? JSONDecoder().decode(ReceiveMessage.self, from: buffer) else {
            messageReceivedSubject.send(completion: .failure(.decodingError))
            return
        }
        
        messageReceivedSubject.send(message)
    }
    
    /// Disconnect the active channel.
    /// - Parameter closeMode: What kind of close operation is requested.
    public mutating func disconnect(
        with closeMode: CloseMode = .all,
        and finishType: Subscribers.Completion<WebSocketError> = .finished
    ) async throws {
        guard let wsUpgrader else { return }
        
        switch try await wsUpgrader.get() {
        case .websocket(let wsChannel):
            do {
                try await wsChannel.channel.close(mode: closeMode)
                self.wsUpgrader = nil
            } catch {
                messageReceivedSubject.send(completion: .failure(.unknownError(error)))
            }
            messageReceivedSubject.send(completion: finishType)
            
            self.logger.info("Channel was disconnected with success.")
        case .notUpgraded:
            return
        }
    }
    
    /// Sends a ping frame for the WebSocket channel.
    private mutating func sendPing() async throws {
        let pingFrame = WebSocketFrame(fin: true, opcode: .ping, data: .init(string: "I'm here."))
        
        guard wsUpgrader != nil else { return }
        
        guard let outboundWriter else {
            messageReceivedSubject.send(completion: .failure(.noConnection))
            try await disconnect()
            return
        }
        
        do {
            try await outboundWriter.write(pingFrame)
        } catch {
            messageReceivedSubject.send(completion: .failure(.unknownError(error)))
            try await disconnect()
        }
    }
    
    /// Sends a message for the WebSocket channel
    /// - Parameter message: The message data representation for send to the channel.
    public mutating func send(_ message: Data) async throws {
        guard wsUpgrader != nil else { return }
        
        guard let outboundWriter else {
            messageReceivedSubject.send(completion: .failure(.noConnection))
            try await disconnect()
            return
        }
        
        let messageByte = [UInt8](message)
        let messageFrame = WebSocketFrame(fin: true, opcode: .binary, data: .init(bytes: messageByte))
        
        do {
            try await outboundWriter.write(messageFrame)
        } catch {
            messageReceivedSubject.send(completion: .failure(.unknownError(error)))
            try await disconnect()
        }
    }
    
    public init(
        configuration: WebSocketSwiftNIOConfiguration,
        eventLoopGroup: MultiThreadedEventLoopGroup = .singleton
    ) {
        self.configuration = configuration
        self.eventLoopGroup = eventLoopGroup
        messageReceivedSubject = .init()
    }
}

extension WebSocketSwiftNIOClient {
    enum UpgradeResult {
        case websocket(NIOAsyncChannel<WebSocketFrame, WebSocketFrame>)
        case notUpgraded
    }
}

