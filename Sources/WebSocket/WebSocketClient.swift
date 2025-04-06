//
//  File.swift
//  NetworkKit
//
//  Created by Isaque da Silva on 3/12/25.
//

import Combine
import NetworkHandler
import Foundation
import Network
import os.log

/// The main representation of the WebSocket client.
@WebSocketActor
public class WebSocketClient: NSObject, Sendable {
    /// Default logger of the WS client.
    private let logger = Logger(
        subsystem: "com.isaqueDaSilva.WebSocket",
        category: "WebSocketClient"
    )
    
    /// Default session that the WebSocket will be created from.
    private let session: URLSession
    
    /// Deafult configuration of the client.
    private let configuration: WebSocketConfiguration
    
    /// Default instance of the network monitor.
    private var monitor: NWPathMonitor?
    
    /// The default representation of the ws channel.
    private var wsTask: URLSessionWebSocketTask?
    
    /// The default ping executor.
    private var pingTask: Task<Void, Never>?
    
    /// A counter that stores the current number of times that we try to send a ping.
    private var pingTryCount = 0
    
    /// A default combine subject that transimit all messages to a top level application.
    public var onReceiveMessageSubject: PassthroughSubject<WebSocketClientMessage, WebSocketError> = .init()
    
    /// A default combine subject that transimit the current state of the connection status.
    public var connectionStateSubject: CurrentValueSubject<ConnectionState, Never> = .init(.disconnected)
    
    /// A representation of the current connection sttae
    private var connectionState: ConnectionState = .disconnected {
        didSet {
            connectionStateSubject.send(connectionState)
        }
    }
    
    /// Establishes a connection in a ws channel.
    public func connect() {
        guard wsTask == nil else {
            logger.info("WebSocket Task is already exists")
            return
        }
        
        guard let request = configuration.endpoint.urlRequest else {
            onReceiveMessageSubject.send(completion: .failure(.notUpgraded))
            logger.error(
                "Cannot possible to make an upgrade in the channel because is missing a url request."
            )
            return
        }
        
        wsTask = session.webSocketTask(with: request)
        wsTask?.delegate = self
        wsTask?.resume()
        
        connectionState = .connecting
        
        logger.info("Starting the channel connection")
    }
    
    /// Send an ``WebSocketClientMessage`` to the channel.
    public func send(_ message: WebSocketClientMessage) async throws(WebSocketError) {
        guard let task = wsTask, connectionState == .connected else {
            logger.error(
                "Cannot possible to send a message. WS Task: \(self.wsTask == nil ? "On" : "Off"); Connection State: \(self.connectionState.rawValue)"
            )
            throw .noConnection
        }
        
        do {
            try await task.send(message)
            logger.info("Message sent with success.")
        } catch {
            logger.error("Failed to send message. Error: \(error.localizedDescription)")
            
            throw .failedToSendData
        }
    }
    
    /// Removes a connection from the channel and the cancels the network monitor execution.
    public func disconnect() {
        disconnect(shouldRemoveNetworkMonitor: true)
    }
    
    /// Removes a connection from the channel.
    /// - Parameter shouldRemoveNetworkMonitor: Defines if you wants to disconnect only the ws channel
    /// or you wants to stop the network monitor as well.
    private func disconnect(shouldRemoveNetworkMonitor: Bool) {
        self.wsTask?.cancel()
        self.wsTask = nil
        self.pingTask?.cancel()
        self.pingTask = nil
        self.connectionState = .disconnected
        if shouldRemoveNetworkMonitor {
            self.monitor?.cancel()
            self.monitor = nil
        }
        
        logger.info("Channel was diconnected with success.")
    }
    
    /// Performs the reconnection from the channel.
    private func reconnect() {
        logger.info("Starting reconnection...")
        self.disconnect(shouldRemoveNetworkMonitor: false)
        self.connect()
    }
    
    /// Handles with the incoming messages.
    private func receiveMessage() {
        self.wsTask?.receive { result in
            Task { @WebSocketActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let message):
                    self.onReceiveMessageSubject.send(message)
                    logger.info("Message transmited with success.")
                case .failure(let failure):
                    self.onReceiveMessageSubject.send(completion: .failure(.unknownError(failure)))
                    logger.error("Error when we receive a message. Error: \(failure.localizedDescription)")
                }
                
                if self.connectionState == .connected {
                    self.receiveMessage()
                }
            }
        }
    }
    
    /// Starts the network monitor.
    private func startMonitorNetworkConnectivity() {
        guard monitor == nil else { return }
        monitor = .init()
        monitor?.pathUpdateHandler = { path in
            Task { @WebSocketActor [weak self] in
                guard let self else { return }
                if path.status == .satisfied, self.wsTask == nil {
                    self.connect()
                    return
                }
                
                if path.status != .satisfied {
                    self.disconnect(shouldRemoveNetworkMonitor: false)
                }
            }
        }
        monitor?.start(queue: .main)
    }
    
    /// Schedule when the ping will be sent to the server.
    private func schedulePing() {
        pingTask?.cancel()
        pingTryCount = 0
        pingTask = Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(self?.configuration.pingInterval ?? 5))
                guard !Task.isCancelled, let self, let task = self.wsTask else { break }
                
                if task.state == .running, self.pingTryCount < self.configuration.pingTryToReconnectCountLimit {
                    self.pingTryCount += 1
                    print("Ping: Send")
                    task.sendPing { error in
                        if let error {
                            print("Ping Failed: \(error.localizedDescription)")
                        } else {
                            print("Ping: Pong Received")
                            Task { @WebSocketActor [weak self] in
                                self?.pingTryCount = 0
                            }
                        }
                    }
                } else {
                    self.reconnect()
                    break
                }
            }
        }
    }
    
    /// Creates a new instance of the ``WebSocketClient``.
    /// - Parameters:
    ///   - configuration: The default configuration of the channel.
    ///   - session: The default URLSession instance that the WebSocket channel will be created,
    nonisolated public init(configuration: WebSocketConfiguration, session: URLSession = .init(configuration: .default)) {
        self.configuration = configuration
        self.session = session
    }
}

extension WebSocketClient: URLSessionWebSocketDelegate {
    
    nonisolated public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        Task { @WebSocketActor [weak self] in
            guard let self else { return }
            
            self.connectionState = .connected
            receiveMessage()
            startMonitorNetworkConnectivity()
            schedulePing()
            
            self.logger.info("Connected on the channel.")
        }
    }
    
    nonisolated public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        Task { @WebSocketActor [weak self] in
            guard let self else { return }
            
            self.connectionState = .disconnected
            
            self.logger.info("Disconnected from the channel.")
        }
    }
    
}
