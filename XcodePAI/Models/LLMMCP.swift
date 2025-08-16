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
    @Published var url: String
    @Published var description: String?
    @Published var headers: [String: String]?
    @Published var enabled: Bool
    
    enum CodingKeys: CodingKey {
        case id
        case name
        case url
        case description
        case headers
        case enabled
    }
    
    init(id: UUID = UUID(), name: String, url: String, description: String? = nil, headers: [String: String]? = nil, enabled: Bool = true) {
        self.id = id
        self.name = name
        self.url = url
        self.description = description
        self.headers = headers
        self.enabled = enabled
    }
    
    // MARK: - Codable
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        url = try container.decode(String.self, forKey: .url)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        headers = try container.decodeIfPresent([String: String].self, forKey: .headers)
        enabled = try container.decode(Bool.self, forKey: .enabled)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(headers, forKey: .headers)
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
        
        return ret
    }
    
    public func checkService(complete: @escaping (Bool, [LLMMCPTool]?) -> Void) {
        Task {[weak self] in
            guard let `self` = self, let url = URL(string: url) else {
                DispatchQueue.main.async {
                    complete(false, nil)
                }
                return
            }
            
            let client = Client(name: Constraint.AppName, version: Constraint.AppVersion)
            
            let transport = HTTPClientTransport(
                endpoint: url,
                streaming: true) {[weak self] request in
                    guard let `self` = self,  let headers = self.headers else {
                        return request
                    }
                    var newRequest = request
                    for key in headers.keys {
                        if let value = headers[key] {
                            newRequest.setValue(value, forHTTPHeaderField: key)
                        }
                    }
                    return newRequest
            }
            
            if let result = try? await client.connect(transport: transport) {
                if result.capabilities.tools != nil {
                    let (tools, _) = try await client.listTools()
                    
                    var mcpTools = [LLMMCPTool]()
                    for tool in tools {
                        mcpTools.append(LLMMCPTool(tool: tool, mcp: self.name))
                    }
                    
                    DispatchQueue.main.async {
                        complete(true, mcpTools)
                    }
                    return
                }
            }
            DispatchQueue.main.async {
                complete(false, nil)
            }
        }
        
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
