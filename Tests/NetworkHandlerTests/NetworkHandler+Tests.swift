//
//  NetworkHandler+Tests.swift
//  NetworkKit
//
//  Created by Isaque da Silva on 1/14/25.
//

import Foundation
@testable import NetworkHandler
import Testing

@Suite(.serialized)
struct NetworkHandlerTest {
    
    @Test(
        "Is getResponse method given the correct response?"
    )
    func isGetResponseGivenBackTheCorrectResponse() async throws {
        let urlSession = URLSession.mockURLSession
        let endpoint = EndpointMock()
        
        let handler = NetworkHandler<ExecutionErrorMock>(
            endpoint: endpoint.endpoint,
            session: urlSession,
            unkwnonURLRequestError: ExecutionErrorMock.failureToCreateAnURLRequest,
            failureToGetDataError: ExecutionErrorMock.runFailure
        )
        
        guard let url = URL(string: endpoint.urlString) else {
            throw ExecutionErrorMock.noURL
        }
        
        URLSessionMock.loadingHandler = {
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
            
            let data = endpoint.data
            
            return (response!, data)
        }
        
        let (data, response) = try await handler.getResponse()
        
        guard let response = response as? HTTPURLResponse else {
            throw ExecutionErrorMock.badResponse
        }
        
        #expect(data == endpoint.data)
        #expect(response.statusCode == 200)
    }
    
    @Test(
        "Is getResponse method thrown correct error when the request failure?"
    )
    func isGetResponseThrownCorrectErrorWhenTheRequestFailure() async throws {
        let urlSession = URLSession.mockURLSession
        let endpoint = EndpointMock()
        
        let handler = NetworkHandler<ExecutionErrorMock>(
            endpoint: endpoint.endpoint,
            session: urlSession,
            unkwnonURLRequestError: ExecutionErrorMock.failureToCreateAnURLRequest,
            failureToGetDataError: ExecutionErrorMock.runFailure
        )
        
        guard let url = URL(string: endpoint.urlString) else {
            throw ExecutionErrorMock.noURL
        }
        
        URLSessionMock.loadingHandler = {
            let response = HTTPURLResponse(
                url: url,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )
            
            return (response!, nil)
        }
        
        let (_, response) = try await handler.getResponse()
        
        guard let response = response as? HTTPURLResponse else {
            throw ExecutionErrorMock.badResponse
        }
        
        #expect(response.statusCode == 401)
    }
}
