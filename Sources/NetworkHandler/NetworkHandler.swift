//
//  NetworkHandler.swift
//  NetworkKit
//
//  Created by Isaque da Silva on 1/14/25.
//

import Foundation

/// Representation layer to handler with network tasks
public struct NetworkHandler<ExecutionError: Error>: Sendable {
    /// An endpoint that will be use to access a desired location.
    private let endpoint: Endpoint
    
    /// An `URLSession`object to use for perform task.
    private let session: URLSession
    
    /// An error that will be used if an error occur when we try to make an URLRequest objet.
    private let unkwnonURLRequestError: ExecutionError
    
    /// An error that will be used if an error occur when we try to perform a task.
    private let failureToGetDataError: ExecutionError
    
    /// Perform desired action on desired location.
    ///
    /// - Returns: Returns a tuple that contains a `Data` and an `URLResponse`
    ///  that coming after the task execution.
    public func getResponse() async throws(ExecutionError) -> (Data, URLResponse) {
        let request = endpoint.makeRequest()
        
        guard let request else {
            throw unkwnonURLRequestError
        }
        
        guard let (data, response) = try? await session.data(for: request) else {
            throw failureToGetDataError
        }
        
        return (data, response)
    }
    
    /// Creates a new instance of a NetworkHandler.
    /// - Parameters:
    ///   - endpoint: An endpoint that will be use to access a desired location.
    ///   - session: An `URLSession`object to use for perform the task.
    ///   - unkwnonURLRequestError: An error that will be used if an error occur
    ///   when we try to make an URLRequest objet.
    ///   - failureToGetDataError: An error that will be used if an error occur
    ///   when we try to perform a task.
    public init(
        endpoint: Endpoint,
        session: URLSession,
        unkwnonURLRequestError: ExecutionError,
        failureToGetDataError: ExecutionError
    ) {
        self.endpoint = endpoint
        self.session = session
        self.unkwnonURLRequestError = unkwnonURLRequestError
        self.failureToGetDataError = failureToGetDataError
    }
}
