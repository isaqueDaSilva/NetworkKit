//
//  File.swift
//  NetworkKit
//
//  Created by Isaque da Silva on 3/11/25.
//

import Foundation
import NIOHTTP1

public struct WSEndpoint: Sendable {
    internal let scheme: String
    internal let host: String
    internal let port: Int
    internal let uri: String
    internal var headers: HTTPHeaders
    
    public init(
        scheme: String,
        host: String,
        port: Int,
        uri: String,
        headers: HTTPHeaders
    ) {
        self.scheme = scheme
        self.host = host
        self.port = port
        self.uri = uri
        self.headers = headers
    }
}
