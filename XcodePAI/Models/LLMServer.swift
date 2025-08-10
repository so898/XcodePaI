//
//  LLMServer.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/10.
//

import Foundation

class LLMServer {
    let url: String
    let authHeaderKey: String
    let privateKey: String?
    
    init(url: String, authHeaderKey: String? = nil, privateKey: String?) {
        self.url = url
        if let authHeaderKey = authHeaderKey {
            self.authHeaderKey = authHeaderKey
        } else {
            self.authHeaderKey = "Authorization"
        }
        self.privateKey = privateKey
    }
    
    func requestHeaders() -> [String: Any]? {
        guard let privateKey = privateKey else {
            return nil
        }
        return [authHeaderKey: "Bearer \(privateKey)", "Content-Type": "application/json"]
    }
}
