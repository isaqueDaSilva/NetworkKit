//
//  URLSessionMock.swift
//  NetworkKit
//
//  Created by Isaque da Silva on 1/14/25.
//

import Foundation

final class URLSessionMock: URLProtocol {
    nonisolated(unsafe) static var loadingHandler: (() -> (HTTPURLResponse, Data?))?
    
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }
    
    override func startLoading() {
        guard let handler = Self.loadingHandler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        
        let (response, data) = handler()
        
        client?.urlProtocol(
            self,
            didReceive: response,
            cacheStoragePolicy: .notAllowed
        )
        
        if let data {
            client?.urlProtocol(self, didLoad: data)
        }
        
        client?.urlProtocolDidFinishLoading(self)
    }
    
    override func stopLoading() { }
}

extension URLSession {
    static var mockURLSession: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLSessionMock.self]
        let session = URLSession(configuration: config)
        return session
    }
}
