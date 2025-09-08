//
//  LLMModelProvider.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/10.
//

import Foundation

class LLMModelProvider: Identifiable, ObservableObject, Codable {
    var id = UUID()
    @Published var name: String
    @Published var iconName: String
    @Published var url: String
    @Published var authHeaderKey: String?
    @Published var privateKey: String?
    @Published var enabled: Bool
    
    var customModelsUrl: String?
    var customChatUrl: String?
    var customCompletionUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, iconName, url, authHeaderKey, privateKey, enabled, customModelsUrl, customChatUrl, customCompletionUrl
    }
    
    init(id: UUID = UUID(), name: String, iconName: String = "ollama", url: String, authHeaderKey: String? = nil, privateKey: String?, enabled: Bool = true, customModelsUrl: String? = nil, customChatUrl: String? = nil, customCompletionUrl: String? = nil) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.url = url
        self.authHeaderKey = authHeaderKey
        self.privateKey = privateKey
        self.enabled = enabled
        self.customModelsUrl = customModelsUrl
        self.customChatUrl = customChatUrl
        self.customCompletionUrl = customCompletionUrl
    }
    
    private func getUrlWithoutLastSplash() -> String {
        return url.hasSuffix("/") ? String(url.dropLast()) : url
    }
    
    private func getUrlWithoutFirstSplash(_ url: String) -> String {
        return url.hasPrefix("/") ? String(url.dropFirst()) : url
    }
    
    func modelListUrl() -> String {
        return getUrlWithoutLastSplash() + "/" + getUrlWithoutFirstSplash(customModelsUrl ?? "/v1/models")
    }
    
    func chatCompletionsUrl() -> String {
        return getUrlWithoutLastSplash() + "/" + getUrlWithoutFirstSplash(customChatUrl ?? "/v1/chat/completions")
    }
    
    func completionsUrl() -> String {
        return getUrlWithoutLastSplash() + "/" + getUrlWithoutFirstSplash(customCompletionUrl ?? "/v1/completions")
    }
    
    func requestHeaders() -> [String: Any] {
        var header: [String: Any] = ["Content-Type": "application/json"]
        guard let privateKey = privateKey else {
            return header
        }
        let authHeaderKey: String = {
            if let authHeaderKey = self.authHeaderKey {
                return authHeaderKey
            }
            return "Authorization"
        }()
        
        if authHeaderKey.lowercased() == "authorization" {
            header[authHeaderKey] = "Bearer \(privateKey)"
        } else {
            header[authHeaderKey] = privateKey
        }
        
        return header
    }
    
    // MARK: - Codable
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        iconName = try container.decode(String.self, forKey: .iconName)
        url = try container.decode(String.self, forKey: .url)
        authHeaderKey = try container.decodeIfPresent(String.self, forKey: .authHeaderKey)
        privateKey = try container.decodeIfPresent(String.self, forKey: .privateKey)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        customModelsUrl = try container.decodeIfPresent(String.self, forKey: .customModelsUrl)
        customChatUrl = try container.decodeIfPresent(String.self, forKey: .customChatUrl)
        customCompletionUrl = try container.decodeIfPresent(String.self, forKey: .customCompletionUrl)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(iconName, forKey: .iconName)
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(authHeaderKey, forKey: .authHeaderKey)
        try container.encodeIfPresent(privateKey, forKey: .privateKey)
        try container.encode(enabled, forKey: .enabled)
        try container.encodeIfPresent(customModelsUrl, forKey: .customModelsUrl)
        try container.encodeIfPresent(customChatUrl, forKey: .customChatUrl)
        try container.encodeIfPresent(customCompletionUrl, forKey: .customCompletionUrl)
    }
}

extension LLMModelProvider: Hashable {
    static func == (lhs: LLMModelProvider, rhs: LLMModelProvider) -> Bool {
        lhs.name == rhs.name && lhs.url == rhs.url && lhs.privateKey == rhs.privateKey && lhs.authHeaderKey == rhs.authHeaderKey && lhs.iconName == rhs.iconName && lhs.id == rhs.id && lhs.customModelsUrl == rhs.customModelsUrl && lhs.customChatUrl == rhs.customChatUrl && lhs.customCompletionUrl == rhs.customCompletionUrl
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
