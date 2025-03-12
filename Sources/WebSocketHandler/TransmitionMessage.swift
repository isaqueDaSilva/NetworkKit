//
//  TransmitionMessage.swift
//  NetworkKit
//
//  Created by Isaque da Silva on 3/11/25.
//

public struct TransmitionMessage: Sendable {
    public let message: any Codable & Sendable
}
