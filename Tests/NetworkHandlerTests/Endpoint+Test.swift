//
//  Endpoint+Test.swift
//  NetworkKit
//
//  Created by Isaque da Silva on 1/14/25.
//

import Foundation
@testable import NetworkHandler
import Testing

struct EndpointTest {

    @Test("Checks if the `makeRequest` method, when it's called, genereted an URLRequest instance correctly")
    func isEndpointGeneratingURLRequestCorrectly() {
        let endpoint = EndpointMock()
        
        let urlRequest = endpoint.urlRequest
        
        #expect(urlRequest != nil)
        #expect(urlRequest?.url?.absoluteString == endpoint.urlString)
        #expect(urlRequest?.httpMethod == endpoint.httpMethod.rawValue)
        #expect(urlRequest?.allHTTPHeaderFields == endpoint.header)
        #expect(urlRequest?.httpBody == endpoint.data)
    }

}
