//
//  BFFClient.swift
//  concertjournal
//
//  Created by Paul Kühnel on 04.02.26.
//

import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case put = "PUT"
    case patch = "PATCH"
    case post = "POST"
    case delete = "DELTE"
}

class BFFClient {
    
    private let baseURL: String
    private let session: URLSession
    
    var getAuthToken: (() async throws -> String)?
    
    init(baseURL: String = "https://concertjournal-bff.vercel.app") {
        self.baseURL = baseURL
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Generic Request
    
    func request<T: Decodable>(
        method: HTTPMethod,
        path: String,
        body: Encodable? = nil
    ) async throws -> T {
        
        guard let url = URL(string: baseURL + path) else {
            throw BFFError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = try? await getAuthToken?() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("LOG: Response is no HTTPURLResponse", response)
            throw BFFError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to decode error
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                let error = BFFError.serverError(errorResponse.error)
                logError("Could not fetch resource for \(request.url?.absoluteString). Response code: \(httpResponse.statusCode)", function: "request")
                throw error
            }
            throw BFFError.httpError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // MARK: - Helper Methods
    
    func get<T: Decodable>(_ path: String, proiderToken: String? = nil) async throws -> T {
        try await request(method: .get, path: path)
    }
    
    func post<T: Decodable>(_ path: String, body: Encodable?) async throws -> T {
        try await request(method: .post, path: path, body: body)
    }

    func put(_ path: String, body: Encodable?) async throws {
        let _: EmptyResponse = try await request(
            method: .put,
            path: path,
            body: body
        )
    }

    func patch<T: Decodable>(_ path: String, body: Encodable?) async throws -> T {
        try await request(method: .patch, path: path, body: body)
    }
    
    func delete(_ path: String) async throws {
        let _: EmptyResponse = try await request(method: .delete, path: path)
    }
}

enum BFFError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP Error: \(code)"
        case .serverError(let message):
            return message
        case .decodingError:
            return "Failed to decode response"
        }
    }
}

struct ErrorResponse: Codable {
    let error: String
}

struct EmptyResponse: Codable {}
