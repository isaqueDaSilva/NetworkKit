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

/// A Client's representation of a WebSocket executor.
@WebSocketActor
public final class WebSocketClient: NSObject, Sendable {
    private let logger = Logger(
        subsystem: "com.isaqueDaSilva.WebSocketHandler",
        category: "WebSocketClient"
    )
    
    private let session: URLSession
    private let configuration: WebSocketConfiguration
    private var monitor: NWPathMonitor?
    private var wsTask: URLSessionWebSocketTask?
    private var pingTask: Task<Void, Never>?
    private var pingTryCount = 0
    private(set) var connectionState: WSConnectionState = .disconnected {
        didSet {
            connectionStateSubject.send(connectionState)
            logger.info("Connection State was changed. New State: \(self.connectionState.rawValue)")
        }
    }
    
    /// A subject that broadcasts on received message to a top-level subscriber.
    public let onReceiveDataSubject: PassthroughSubject<WSMessage, Error> = .init()
    
    /// A subject that broadcasts the current connection state message to a top-level subscriber.
    public let connectionStateSubject: PassthroughSubject<WSConnectionState, Never> = .init()
    
    /// Performs the connection into a WebSocket channel.
    public func connect() {
        guard wsTask == nil else {
            logger.info("The WebSocket task handler already exists")
            return
        }
        
        guard let urlRequest = configuration.endpoint.urlRequest else {
            logger.info("There are no url request stored in the configuration.")
            return
        }
        
        self.wsTask = session.webSocketTask(with: urlRequest)
        self.wsTask?.delegate = self
        self.wsTask?.resume()
        
        self.connectionState = .connecting
        startMonitorNetworkConnectivity()
    }
    
    /// Performs the disconnection into a WebSocket channel.
    public func disconnect() {
        disconnect(shouldRemoveNetworkMonitor: true, closeCode: .normalClosure)
    }
    
    /// Enables the easy reconnection in the channel.
    ///
    /// >Note: This reconnect method do not restart the `NWPathMonitor` object. If you want to restart the monitor as well, we strongly recommend to call the ``disconnect()`` method and after call then ``connect()`` method.
    public func reconnect() {
        disconnect(shouldRemoveNetworkMonitor: false, closeCode: .normalClosure)
        connect()
    }
    
    private func disconnect(shouldRemoveNetworkMonitor: Bool, closeCode: CloseCode) {
        self.wsTask?.cancel(with: closeCode, reason: nil)
        self.wsTask = nil
        self.pingTask?.cancel()
        self.pingTask = nil
        
        if shouldRemoveNetworkMonitor {
            self.monitor?.cancel()
            self.monitor = nil
            self.connectionStateSubject.send(completion: .finished)
            self.onReceiveDataSubject.send(completion: .finished)
        }
    }
    
    /// Send a message into a channel.
    /// - Parameter message: The message representation that'll send into the WebSocket channel.
    public func sendMessage(_ message: WSMessage) async throws {
        guard let wsTask, connectionState == .connected else {
            throw NSError(
                domain: "WebSocketHandler",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "WebSocket is not connected."]
            )
        }
        
        try await wsTask.send(message)
    }
    
    private func receiveMessage() {
        guard let wsTask, connectionState == .connected else {
            logger.info(
                "Abort check if has message. Status: WS Task: \(self.wsTask == nil ? "Inactive" : "Active"); Connection State: \(self.connectionState.rawValue)"
            )
            return
        }
        
        logger.info("Start.")
        
        Task { @WebSocketActor [weak self] in
            guard let self else { return }
            
            do {
                let message = try await wsTask.receive()
                self.onReceiveDataSubject.send(message)
                logger.info("Receive and transmit the message with success.")
            } catch {
                self.onReceiveDataSubject.send(completion: .failure(error))
                logger.error("Failed to receive message.")
            }
            
            if self.connectionState == .connected {
                self.receiveMessage()
            }
        }
    }
    
    private func startMonitorNetworkConnectivity() {
        guard monitor == nil else { return }
        
        self.monitor = .init()
        
        self.monitor?.pathUpdateHandler = { path in
            Task { @WebSocketActor [weak self] in
                guard let self else { return }
                
                if path.status == .satisfied && self.wsTask == nil {
                    self.connect()
                    return
                }
                
                if path.status != .satisfied {
                    self.disconnect(shouldRemoveNetworkMonitor: false, closeCode: .internalServerError)
                }
            }
        }
        
        self.monitor?.start(queue: .main)
    }
    
    private func sendPing() {
        self.pingTask?.cancel()
        self.pingTryCount = 0
        
        self.pingTask = Task { [weak self] in
            guard let self else { return }
            
            try? await Task.sleep(for: .seconds(self.configuration.pingTryToReconnectCountLimit))
            
            guard let pingTask, !pingTask.isCancelled, let wsTask else { return }
            
            if wsTask.state == .running, self.pingTryCount < self.configuration.pingTryToReconnectCountLimit {
                self.pingTryCount += 1
                logger.info("Ping: Send")
                
                wsTask.sendPing { [weak self] error in
                    Task { @WebSocketActor [weak self] in
                        guard let self else { return }
                        
                        if let error {
                            self.logger.error("Failed to send ping: Error \(error.localizedDescription)")
                        } else {
                            self.logger.info("Ping: Pong received with success.")
                            self.pingTryCount = 0
                            
                            if self.connectionState == .connected {
                                self.sendPing()
                            }
                        }
                    }
                }
            } else {
                self.reconnect()
            }
        }
    }
    
    /// Creates a new WebSocket client type.
    nonisolated public init(
        session: URLSession = .shared,
        configuration: WebSocketConfiguration
    ) {
        self.session = session
        self.configuration = configuration
    }
    
    deinit {
        Task { @WebSocketActor [weak self] in
            guard let self else { return }
            
            self.disconnect(shouldRemoveNetworkMonitor: true, closeCode: .normalClosure)
        }
    }
}

extension WebSocketClient: URLSessionWebSocketDelegate {
    nonisolated public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        Task { @WebSocketActor [weak self] in
            guard let self else { return }
            
            self.connectionState = .connected
            receiveMessage()
            sendPing()
        }
    }
    
    nonisolated public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        Task { @WebSocketActor [weak self] in
            guard let self else { return }
            
            self.connectionState = .disconnected
            
            self.connectionStateSubject.send(completion: .finished)
            self.onReceiveDataSubject.send(completion: .finished)
        }
    }
}
