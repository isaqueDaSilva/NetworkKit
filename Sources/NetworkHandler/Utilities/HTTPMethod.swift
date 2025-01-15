//
//  HTTPMethod.swift
//  NetworkKit
//
//  Created by Isaque da Silva on 1/14/25.
//


/// Stores the all HTTP methods.
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}
