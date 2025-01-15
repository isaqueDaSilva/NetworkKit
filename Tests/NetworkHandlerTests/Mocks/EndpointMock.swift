//
//  File.swift
//  NetworkKit
//
//  Created by Isaque da Silva on 1/14/25.
//

import Foundation
@testable import Common

struct EndpointMock {
    let scheme = "http"
    let host = "localhost"
    let path = "/hello-world"
    let httpMethod = HTTPMethod.get
    let header = ["Authorization": "someValue"]
    let data = Data()
    let urlString = "http://localhost/hello-world"
    
    var endpoint: Endpoint {
        Endpoint(
            scheme: scheme,
            host: host,
            path: path,
            httpMethod: httpMethod,
            headers: header,
            body: data
        )
    }
    
    var urlRequest: URLRequest? {
        endpoint.makeRequest()
    }
}
