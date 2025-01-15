//
//  ErrorMock.swift
//  NetworkKit
//
//  Created by Isaque da Silva on 1/14/25.
//

import Foundation

enum ExecutionErrorMock: Error {
    case failureToCreateAnURLRequest
    case runFailure
    case noURL
    case badResponse
}
