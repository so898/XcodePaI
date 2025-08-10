//
//  HTTPClient.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/10.
//

import Foundation

class HTTPClient {
    
    static func get(url: String, headers: [String: Any]? = nil, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let url = URL(string: url) else {
            completion(.failure(NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "url parser fail"])))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers?.forEach { key, value in
            if let value = value as? String {
                request.addValue(value, forHTTPHeaderField: key)
            } else if let value = value as? Int {
                request.addValue(String(value), forHTTPHeaderField: key)
            } else if let value = value as? Double {
                request.addValue(String(value), forHTTPHeaderField: key)
            }
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let data = data else {
                completion(.failure(NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response or no data"])))
                return
            }
            completion(.success(data))
        }.resume()
    }
    
    static func post(url: String, headers: [String: Any]? = nil, body: Data?, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let url = URL(string: url) else {
            completion(.failure(NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "url parser fail"])))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        headers?.forEach { key, value in
            if let value = value as? String {
                request.addValue(value, forHTTPHeaderField: key)
            } else if let value = value as? Int {
                request.addValue(String(value), forHTTPHeaderField: key)
            } else if let value = value as? Double {
                request.addValue(String(value), forHTTPHeaderField: key)
            }
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let data = data else {
                completion(.failure(NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response or no data"])))
                return
            }
            completion(.success(data))
        }.resume()
    }
}
