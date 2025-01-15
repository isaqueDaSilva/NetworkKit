//
//  Request.swift
//  NetworkKit
//
//  Created by Isaque da Silva on 1/14/25.
//

import Foundation

/// A representation model that stores a method
/// that creates an URLRequest instances to perform tasks.
internal enum Request: Sendable {
    /// Creates a URLRequest instance.
    /// - Parameters:
    ///   - url: An URL represenation to desired endpoint.
    ///   - httpMethod: The HTTP method desired to perform an action.
    ///   - headers: A collection of headers necessaries to perform task.
    ///   - body: The optional data to send in the request.
    /// - Returns: Returns an instance of an URLRequest configured with desired parameters.
    internal static func makeRequest(
        forURL url: URL,
        httpMethod: HTTPMethod,
        headers: [String: String]?,
        body: Data?
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        request.allHTTPHeaderFields = headers
        request.httpBody = body
        return request
    }
}
