//
//  HTTPClient.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/10.
//

import Foundation
import Logger

class HTTPClient {
    
    static func get(url: String, headers: [String: Any]? = nil, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let url = URL(string: url) else {
            completion(.failure(NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "url parser fail"])))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addHeaders(headers)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let data = data else {
                let content: String? = {
                    if let data {
                        return String(data: data, encoding: .utf8)
                    }
                    return nil
                }()
                Logger.service.error("Client Request: GET \(url.absoluteString)\nReturn: \((response as? HTTPURLResponse)?.statusCode ?? -1)\nContent: \(content ?? "")")
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
        request.addHeaders(headers)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let data = data else {
                let content: String? = {
                    if let data {
                        return String(data: data, encoding: .utf8)
                    }
                    return nil
                }()
                Logger.service.error("Client Request: POST \(url.absoluteString)\nReturn: \((response as? HTTPURLResponse)?.statusCode ?? -1)\nContent: \(content ?? "")")
                completion(.failure(NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response or no data"])))
                return
            }
            completion(.success(data))
        }.resume()
    }
}
