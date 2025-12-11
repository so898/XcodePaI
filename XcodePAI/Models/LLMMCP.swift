//
//  LLMMCP.swift
//  XcodePAI
//
//  Created by Bill Cheng on 8/15/25.
//

import Foundation
import MCP

class LLMMCP: Identifiable, ObservableObject, Codable {
    var id = UUID()
    @Published var name: String
    @Published var description: String?

    // For Remote
    @Published var url: String
    @Published var headers: [String: String]?
    
    // For Local
    @Published var command: String?
    @Published var args: [String]?
    
    @Published var enabled: Bool
    
    enum CodingKeys: CodingKey {
        case id
        case name
        case description
        case url
        case headers
        case command
        case args
        case enabled
    }
    
    init(id: UUID = UUID(), name: String, description: String? = nil, url: String, headers: [String: String]? = nil, enabled: Bool = true) {
        self.id = id
        self.name = name
        self.url = url
        self.description = description
        self.headers = headers
        self.enabled = enabled
    }
    
    init(id: UUID = UUID(), name: String, description: String? = nil, command: String?, args:[String]?, enabled: Bool = true) {
        self.id = id
        self.name = name
        self.description = description
        self.url = "local"
        self.command = command
        self.args = args
        self.enabled = enabled
    }
    
    // MARK: - Codable
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        
        url = try container.decode(String.self, forKey: .url)
        headers = try container.decodeIfPresent([String: String].self, forKey: .headers)
        
        command = try container.decodeIfPresent(String.self, forKey: .command)
        args = try container.decodeIfPresent([String].self, forKey: .args)
        
        enabled = try container.decode(Bool.self, forKey: .enabled)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(headers, forKey: .headers)
        
        try container.encodeIfPresent(command, forKey: .command)
        try container.encodeIfPresent(args, forKey: .args)
        
        try container.encode(enabled, forKey: .enabled)
    }
    
    // MARK: - Utilities
    public func toDictionary() -> [String: Any] {
        var ret: [String: Any] = [
            "id": id,
            "name": name,
            "url": url,
            "enabled": enabled
        ]
        
        if let description = description {
            ret["description"] = description
        }
        
        if let headers = headers {
            ret["headers"] = headers
        }
        
        if let command = command {
            ret["command"] = command
        }
        
        if let args = args {
            ret["args"] = args
        }
        
        return ret
    }
    
    public func isLocal() -> Bool {
        return url == "local"
    }
}

extension LLMMCP: Hashable {
    static func == (lhs: LLMMCP, rhs: LLMMCP) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.url == rhs.url && lhs.description == rhs.description && lhs.headers == rhs.headers && lhs.enabled == rhs.enabled
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
