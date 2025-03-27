//
//  Endpoint.swift
//  NetworkKit
//
//  Created by Isaque da Silva on 1/14/25.
//

import Foundation

/// Representation structure to make an Endpoint,
public struct Endpoint: Sendable {
    /// String representation of what representation
    /// or diagram that outlines the configuration
    /// and relationships of a computer network like `https`.
    private let scheme: String
    
    /// The host's representation of the place where it will be accessed.
    private let host: String
    
    /// The path representation to access an specific URI of the host.
    private let path: String
    
    /// The HTTP method that we'll used to access or perform action in the URI.
    private let httpMethod: HTTPMethod
    
    /// The headers that we'll utilize to make request.
    private let headers: [String: String]?
    
    /// The data that will be send to the request
    private let body: Data?
    
    public var urlRequest: URLRequest? {
        makeRequest()
    }
    
    /// Creates an URLRequest instance to perform the desired task.
    /// - Returns: Returns a configured URLRequest instance to perform task.
    internal func makeRequest() -> URLRequest? {
        let url = URL(string: "\(scheme)://\(host)/\(path)")
        
        guard let url else {
            return nil
        }
        
        let request = Request.makeRequest(
            forURL: url,
            httpMethod: httpMethod,
            headers: headers,
            body: body
        )
        
        return request
    }
    
    /// Creates a new instance of the Endpoint type.
    /// - Parameters:
    ///   - scheme: Representation that outlines the configuration
    ///   and relationships of a computer network like `https`.
    ///   - host: Rpresentation of the place where it will be accessed.
    ///   - path: Representation of an specific URI of the host.
    ///   - httpMethod: The HTTP method that we'll used to perform the task.
    ///   - headers: Desired HTTP headers to utilize to make request.
    ///   - body: An optional data to be send when the task will performed.
    public init(
        scheme: String = "https",
        host: String,
        path: String,
        httpMethod: HTTPMethod,
        headers: [String : String]? = nil,
        body: Data? = nil
    ) {
        self.scheme = scheme
        self.host = host
        self.path = path
        self.httpMethod = httpMethod
        self.headers = headers
        self.body = body
    }
}

