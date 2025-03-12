//
//  File.swift
//  NetworkKit
//
//  Created by Isaque da Silva on 1/14/25.
//

@preconcurrency import Combine
import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOWebSocket
import NIOFoundationCompat

public struct WebSocketHandler<ReceivedMessage: Codable & Sendable, ExecutionError: Error> : Sendable{
    /// A representation path to find the desired path to open the connection
    private let endpoint: WSEndpoint
    
    /// A default event loop group to make active the WebSocket connection.
    private let eventLoopGroup: MultiThreadedEventLoopGroup
    
    /// A default WebSocket Upgrader for this aplication.
    private var wsUpgrader: EventLoopFuture<UpgradeResult>?
    
    private var outboundWriter: NIOAsyncChannelOutboundWriter<WebSocketFrame>?
    
    /// The default Combine's subject that stores the current message or an error to send back to the top level aplication.
    public let messageReceivedSubject: PassthroughSubject<TransmitionMessage, ExecutionError>
    
    private let decodingError: ExecutionError
    private let unknownError: ExecutionError
    private let noConnection: ExecutionError
    
    /// Establish the WebSoclet channel connection
    /// - Returns: Returns a `EventLoopFuture` for handle with the WebSocket channel
    private func getUpgraderResult() async throws -> EventLoopFuture<UpgradeResult> {
        let upgradeResult: EventLoopFuture<UpgradeResult> = try await ClientBootstrap(group: eventLoopGroup)
            .connect(
                host: self.endpoint.host,
                port: self.endpoint.port
            ) { channel in
                channel.eventLoop.makeCompletedFuture {
                    let upgrader = NIOTypedWebSocketClientUpgrader<UpgradeResult> { (channel, _) in
                        channel.eventLoop.makeCompletedFuture {
                            let asyncChannel = try NIOAsyncChannel<WebSocketFrame, WebSocketFrame>(wrappingChannelSynchronously: channel)
                            return UpgradeResult.websocket(asyncChannel)
                        }
                    }
                    
                    var headers = endpoint.headers
                    headers.add(name: "Content-Type", value: "application/vnd.api+json")
                    
                    let requestHead = HTTPRequestHead(
                        version: .http1_1,
                        method: .GET,
                        uri: self.endpoint.uri,
                        headers: headers
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
        
        return upgradeResult
    }
    
    /// Handles with the upgrade result.
    private mutating func upgradeChannel() async throws {
        guard let wsUpgrader else {
            return try await disconnect()
        }
        
        switch try await wsUpgrader.get() {
        case .websocket(let wsChannel):
            print("Handling websocket connection...")
            try await handleWebsocketChannel(with: wsChannel)
            try await disconnect()
            print("Done handling websocket connection.")
        case .notUpgraded:
            print("Upgrade declined.")
        }
    }
    
    /// Starts the WebSocket channel and observers the all messages that coming when the channel is alive.
    /// - Parameter channel: The actual WebSocket channel.
    private mutating func handleWebsocketChannel(
        with channel: NIOAsyncChannel<WebSocketFrame, WebSocketFrame>
    ) async throws {
        // Executes the channel.
        try await channel.executeThenClose { inbound, outbound in
            outboundWriter = outbound
            
            // Creates a stream for receive
            // the all data that coming
            // from the WebSocket channel.
            for try await frame in inbound {
                switch frame.opcode {
                case .binary:
                    onReceive(frame.data, for: ReceivedMessage.self)
                case .text:
                    onReceive(frame.data, for: String.self)
                case .pong:
                    try await sendPing()
                case .connectionClose:
                    try await disconnect()
                default:
                    print("Message received isn't valid")
                    try await disconnect()
                    break
                }
            }
        }
    }
    
    /// Handles with the messages that received from the channel.
    /// - Parameter buffer: The buffer that stores the binary data representation for the message.
    private func onReceive<T: Codable & Sendable>(_ buffer: ByteBuffer, for type: T.Type) {
        guard let message = try? JSONDecoder().decode(T.self, from: buffer) else {
            messageReceivedSubject.send(completion: .failure(decodingError))
            return
        }
        
        let transmitionMessage = TransmitionMessage(message: message)
        
        messageReceivedSubject.send(transmitionMessage)
    }
    
    /// Disconnect the active channel.
    /// - Parameter closeMode: What kind of close operation is requested.
    public mutating func disconnect(
        with closeMode: CloseMode = .all,
        and finishType: Subscribers.Completion<ExecutionError> = .finished
    ) async throws {
        guard let wsUpgrader else { return }
        
        switch try await wsUpgrader.get() {
        case .websocket(let wsChannel):
            do {
                try await wsChannel.channel.close(mode: closeMode)
                self.wsUpgrader = nil
            } catch {
                messageReceivedSubject.send(completion: .failure(unknownError))
            }
            messageReceivedSubject.send(completion: finishType)
        case .notUpgraded:
            return
        }
    }
    
    /// Sends a ping frame for the WebSocket channel.
    public mutating func sendPing() async throws {
        let pingFrame = WebSocketFrame(fin: true, opcode: .ping, data: .init(string: "I'm here."))
        
        guard wsUpgrader != nil else { return }
        
        guard let outboundWriter else {
            messageReceivedSubject.send(completion: .failure(noConnection))
            try await disconnect()
            return
        }
        
        do {
            try await outboundWriter.write(pingFrame)
        } catch {
            messageReceivedSubject.send(completion: .failure(unknownError))
            try await disconnect()
        }
    }
    
    /// Sends a message for the WebSocket channel
    /// - Parameter message: The message data representation for send to the channel.
    public mutating func send(_ message: Data) async throws {
        guard wsUpgrader != nil else { return }
        
        guard let outboundWriter else {
            messageReceivedSubject.send(completion: .failure(noConnection))
            try await disconnect()
            return
        }
        
        let messageByte = [UInt8](message)
        let messageFrame = WebSocketFrame(fin: true, opcode: .binary, data: .init(bytes: messageByte))
        
        do {
            try await outboundWriter.write(messageFrame)
        } catch {
            messageReceivedSubject.send(completion: .failure(unknownError))
            try await disconnect()
        }
    }
    
    init(
        endpoint: WSEndpoint,
        eventLoopGroup: MultiThreadedEventLoopGroup,
        decodingError: ExecutionError,
        unknownError: ExecutionError,
        noConnection: ExecutionError
    ) {
        self.endpoint = endpoint
        self.eventLoopGroup = eventLoopGroup
        self.messageReceivedSubject = .init()
        self.decodingError = decodingError
        self.unknownError = unknownError
        self.noConnection = noConnection
    }
}
