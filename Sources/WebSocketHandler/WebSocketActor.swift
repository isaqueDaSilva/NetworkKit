//
//  File.swift
//  NetworkKit
//
//  Created by Isaque da Silva on 3/12/25.
//

/// Default executor for ``WebSocketClient``.
@globalActor public actor WebSocketActor {
    public static let shared = WebSocketActor()
    
    private init() { }
}
