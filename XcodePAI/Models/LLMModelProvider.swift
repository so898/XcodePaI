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
    
    enum CodingKeys: String, CodingKey {
        case id, name, iconName, url, authHeaderKey, privateKey, enabled
    }
    
    init(id: UUID = UUID(), name: String, iconName: String = "ollama", url: String, authHeaderKey: String? = nil, privateKey: String?, enabled: Bool = true) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.url = url
        self.authHeaderKey = authHeaderKey
        self.privateKey = privateKey
        self.enabled = enabled
    }
    
    func modelListUrl() -> String {
        return url + "/v1/models"
    }
    
    func completionsUrl() -> String {
        return url + "/v1/completions"
    }
    
    func chatCompletionsUrl() -> String {
        return url + "/v1/chat/completions"
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
    }
}

extension LLMModelProvider: Hashable {
    static func == (lhs: LLMModelProvider, rhs: LLMModelProvider) -> Bool {
        lhs.name == rhs.name && lhs.url == rhs.url && lhs.privateKey == rhs.privateKey && lhs.authHeaderKey == rhs.authHeaderKey && lhs.iconName == rhs.iconName && lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
