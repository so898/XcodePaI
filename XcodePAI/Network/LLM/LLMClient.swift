//
//  LLMClient.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/10.
//

import Foundation

class LLMClient {
    
    private let server: LLMServer
    private var client: HTTPSSEClient?
    
    init(_ server: LLMServer) {
        self.server = server
    }
    
    func request(_ request: LLMRequest) {
        guard let data = try? JSONSerialization.data(withJSONObject: request.toDictionary()) else {
            return
        }
        
        client = HTTPSSEClient(url: server.url, headers: server.requestHeaders(), body: data, delegate: self)
        client?.start()
    }
    
}

extension LLMClient: HTTPSSEClientDelegate {
    func client(_ client: HTTPSSEClient, receive chunk: String) {
        if chunk == "[DONE]" {
            // End of completions
            client.cancel()
            print("sm.pro: END")
            return
        }
        guard let data = chunk.data(using: .utf8), let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        let response = LLMResponse(dict: dict)
        print("sm.pro: \(response.toDictionary())")
    }
    
    func client(_ client: HTTPSSEClient, complete: Result<Void, any Error>) {
        
    }
}
