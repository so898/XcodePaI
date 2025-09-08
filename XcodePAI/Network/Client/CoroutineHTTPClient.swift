//
//  CoroutineHTTPClient.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/9/5.
//

import Foundation

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

enum CoroutineHTTPClientError: Error, LocalizedError {
    case invalidURL
    case encodingError
    case invalidResponse
    case httpError(statusCode: Int, content: String?)
    case decodingError
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .httpError(let statusCode, let content):
            return "HTTP error: Status code \(statusCode)\(content == nil ? "" : "\nResponse: \(content!)")"
        case .decodingError:
            return "Decoding error"
        case .encodingError:
            return "Encoding error"
        case .invalidURL:
            return  "Invalid URL"
        case .unknown(let error):
            return "Unknown error: \(error)"
        case .invalidResponse:
            return "Invalid Response"
        }
    }
}

class CoroutineHTTPClient {
    
    // Singleton instance
    static let shared = CoroutineHTTPClient()
    private init() {}
    
    /// Generic network request method
    /// - Parameters:
    ///   - url: Request URL
    ///   - method: HTTP method (default: .get)
    ///   - headers: HTTP headers
    ///   - body: Request body data
    /// - Returns: Decoded response of type T
    private func request<T: Decodable>(
        url: URL?,
        method: HTTPMethod = .get,
        headers: [String: Any]? = nil,
        body: Data? = nil
    ) async throws -> T {
        
        guard let url = url else {
            throw CoroutineHTTPClientError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        
//        if let body, let str = String(data: body, encoding: .utf8) {
//            print("\(str)")
//        }
        
        // Add headers
        headers?.forEach { key, value in
            if let value = value as? String {
                request.addValue(value, forHTTPHeaderField: key)
            } else if let value = value as? Int {
                request.addValue(String(value), forHTTPHeaderField: key)
            } else if let value = value as? Double {
                request.addValue(String(value), forHTTPHeaderField: key)
            }
        }
        
        // Set default Content-Type for non-GET requests with body
        if method != .get, body != nil {
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
//        if let str = String(data: data, encoding: .utf8) {
//            print("\(str)")
//        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CoroutineHTTPClientError.invalidResponse
        }
        
        // Check for successful status codes (200-299)
        guard (200...299).contains(httpResponse.statusCode) else {
            let content: String? = String(data: data, encoding: .utf8)
            throw CoroutineHTTPClientError.httpError(statusCode: httpResponse.statusCode, content: content)
        }
        
        do {
            let decodedData = try JSONDecoder().decode(T.self, from: data)
            return decodedData
        } catch {
            throw CoroutineHTTPClientError.decodingError
        }
    }
    
    static func POST(
        urlString: String,
        headers: [String: Any]? = nil,
        body: Data? = nil
    ) async throws -> Data {
        
        guard let url = URL(string: urlString) else {
            throw CoroutineHTTPClientError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        
        // Add headers
        headers?.forEach { key, value in
            if let value = value as? String {
                request.addValue(value, forHTTPHeaderField: key)
            } else if let value = value as? Int {
                request.addValue(String(value), forHTTPHeaderField: key)
            } else if let value = value as? Double {
                request.addValue(String(value), forHTTPHeaderField: key)
            }
        }
        
        // Set default Content-Type for non-GET requests with body
        if body != nil {
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CoroutineHTTPClientError.invalidResponse
        }
        
        // Check for successful status codes (200-299)
        guard (200...299).contains(httpResponse.statusCode) else {
            let content: String? = String(data: data, encoding: .utf8)
            throw CoroutineHTTPClientError.httpError(statusCode: httpResponse.statusCode, content: content)
        }
        
        return data
    }
    
    // MARK: - GET Requests
    
    /// Perform GET request
    /// - Parameters:
    ///   - urlString: URL string
    ///   - headers: HTTP headers
    /// - Returns: Decoded response data
    func get<T: Decodable>(
        _ urlString: String,
        headers: [String: Any]? = nil
    ) async throws -> T {
        
        guard let url = URL(string: urlString) else {
            throw CoroutineHTTPClientError.invalidURL
        }
        
        return try await request(url: url, method: .get, headers: headers)
    }
    
    // MARK: - POST Requests
    
    /// Perform POST request with Encodable body
    /// - Parameters:
    ///   - urlString: URL string
    ///   - body: Encodable request body
    ///   - headers: HTTP headers
    /// - Returns: Decoded response data
    func post<T: Decodable, U: Encodable>(
        _ urlString: String,
        body: U,
        headers: [String: Any]? = nil
    ) async throws -> T {
        
        guard let url = URL(string: urlString) else {
            throw CoroutineHTTPClientError.invalidURL
        }
        
        let bodyData = try JSONEncoder().encode(body)
        
        return try await request(
            url: url,
            method: .post,
            headers: headers,
            body: bodyData
        )
    }
    
    /// Perform POST request with Dictionary parameters
    /// - Parameters:
    ///   - urlString: URL string
    ///   - parameters: Request parameters as dictionary
    ///   - headers: HTTP headers
    /// - Returns: Decoded response data
    func post<T: Decodable>(
        _ urlString: String,
        parameters: [String: Any],
        headers: [String: Any]? = nil
    ) async throws -> T {
        
        guard let url = URL(string: urlString) else {
            throw CoroutineHTTPClientError.invalidURL
        }
        
        let bodyData = try JSONSerialization.data(withJSONObject: parameters)
        
        return try await request(
            url: url,
            method: .post,
            headers: headers,
            body: bodyData
        )
    }
    
    /// Perform POST request without body
    /// - Parameters:
    ///   - urlString: URL string
    ///   - headers: HTTP headers
    /// - Returns: Decoded response data
    func post<T: Decodable>(
        _ urlString: String,
        headers: [String: Any]? = nil
    ) async throws -> T {
        
        guard let url = URL(string: urlString) else {
            throw CoroutineHTTPClientError.invalidURL
        }
        
        return try await request(
            url: url,
            method: .post,
            headers: headers
        )
    }
}

// Extension for direct URLSession usage with async/await
extension URLSession {
    func data(from request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = self.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data = data, let response = response else {
                    continuation.resume(throwing: CoroutineHTTPClientError.invalidResponse)
                    return
                }
                continuation.resume(returning: (data, response))
            }
            task.resume()
        }
    }
}
