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

@WebSocketActor
class WebSocketClient: NSObject, Sendable {
    private let logger = Logger(
        subsystem: "com.isaqueDaSilva.WebSocket",
        category: "WebSocketClient"
    )
    
    private let session: URLSession
    private let configuration: WebSocketConfiguration
    
    private var monitor: NWPathMonitor?
    private var wsTask: URLSessionWebSocketTask?
    private var pingTask: Task<Void, Never>?
    private var pingTryCount = 0
    
    var onReceive: ((WebSocketClientMessage) -> Void)?
    var errorHandler: ((WebSocketError) -> Void)?
    var onConnectionStateChange: ((ConnectionState) -> Void)?
    
    private(set) var connectionState = ConnectionState.disconnected {
        didSet {
            onConnectionStateChange?(connectionState)
        }
    }
    
    func connect() {
        guard wsTask == nil else {
            logger.info("WebSocket Task is already exists")
            return
        }
        
        guard let request = configuration.endpoint.urlRequest else {
            errorHandler?(.notUpgraded)
            logger.error(
                "Cannot possible to make an upgrade in the channel because is missing a url request."
            )
            return
        }
        
        wsTask = session.webSocketTask(with: request)
        wsTask?.delegate = self
        wsTask?.resume()
        
        logger.info("Starting the channel connection")
        
        connectionState = .connecting
        receiveMessage()
        startMonitorNetworkConnectivity()
        schedulePing()
        
    }
    
    func send(_ message: WebSocketClientMessage) async throws(WebSocketError) {
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
    
    func disconnect() {
        disconnect(shouldRemoveNetworkMonitor: true)
    }
    
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
    
    private func reconnect() {
        logger.info("Starting reconnection...")
        self.disconnect(shouldRemoveNetworkMonitor: false)
        self.connect()
    }
    
    private func receiveMessage() {
        self.wsTask?.receive { result in
            Task { @WebSocketActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let message):
                    self.onReceive?(message)
                    logger.info("Message transmited with success.")
                case .failure(let failure):
                    self.errorHandler?(.unknownError(failure))
                    logger.error("Error when we receive a message. Error: \(failure.localizedDescription)")
                }
                
                if self.connectionState == .connected {
                    self.receiveMessage()
                }
            }
        }
    }
    
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
    
    nonisolated init(configuration: WebSocketConfiguration, session: URLSession = .init(configuration: .default)) {
        self.configuration = configuration
        self.session = session
    }
}


extension WebSocketClient: URLSessionWebSocketDelegate {
    
    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        Task { @WebSocketActor [weak self] in
            self?.connectionState = .connected
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        Task { @WebSocketActor [weak self] in
            self?.connectionState = .disconnected
        }
    }
    
}
