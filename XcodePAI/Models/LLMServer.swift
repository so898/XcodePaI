//
//  LLMServer.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/10.
//

import Foundation

class LLMServer: Codable, Identifiable {
    let name: String
    let iconName: String
    let url: String
    let authHeaderKey: String
    let privateKey: String?
    
    init(name: String, iconName: String = "ollama", url: String, authHeaderKey: String? = nil, privateKey: String?) {
        self.name = name
        self.iconName = iconName
        self.url = url
        if let authHeaderKey = authHeaderKey {
            self.authHeaderKey = authHeaderKey
        } else {
            self.authHeaderKey = "Authorization"
        }
        self.privateKey = privateKey
    }
    
    func modelListUrl() -> String {
        return url + "/v1/models"
    }
    
    func chatCompletionsUrl() -> String {
        return url + "/v1/chat/completions"
    }
    
    func requestHeaders() -> [String: Any]? {
        guard let privateKey = privateKey else {
            return nil
        }
        return [authHeaderKey: "Bearer \(privateKey)", "Content-Type": "application/json"]
    }
}
