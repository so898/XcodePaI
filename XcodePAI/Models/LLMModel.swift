//
//  LLMModel.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/9.
//

import Foundation

typealias ChatProxyLLMModel = LLMModel

class LLMModel: Identifiable, ObservableObject, Codable {
    @Published var id: String
    let object: String
    var provider: String
    @Published var enabled: Bool
    let created: Int // Create Timestamp
    
    enum CodingKeys: String, CodingKey {
        case id, object, provider, enabled, created
    }
    
    init(id: String, object: String = "model", provider: String, enabled: Bool = true, created: Int = Int(Date().timeIntervalSince1970)) {
        self.id = id
        self.object = object
        self.provider = provider
        self.enabled = enabled
        self.created = created
    }
    
    convenience init(id: String, created: Int = Int(Date().timeIntervalSince1970)) {
        self.init(id: id, object: "model", provider:Constraint.AppName, created: created)
    }
    
    init(_ dict: [String: Any], provider: String) {
        if let id = dict["id"] as? String {
            self.id = id
        } else {
            fatalError("LLM model could not be properly parsered.")
        }
        
        if let object = dict["object"] as? String {
            self.object = object
        } else {
            fatalError("LLM model could not be properly parsered.")
        }
        
        self.provider = provider
        self.enabled = true
        
        if let created = dict["created"] as? Int {
            self.created = created
        } else {
            self.created = Int(Date().timeIntervalSince1970)
        }
    }
    
    // MARK: - Codable
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        object = try container.decode(String.self, forKey: .object)
        provider = try container.decode(String.self, forKey: .provider)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        created = try container.decode(Int.self, forKey: .created)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(object, forKey: .object)
        try container.encode(provider, forKey: .provider)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(created, forKey: .created)
    }
    
    public func toDictionary() -> [String: Any] {
        return ["id": id, "object": object, "created": created, "owned_by": provider]
    }
}

extension LLMModel: Hashable {
    static func == (lhs: LLMModel, rhs: LLMModel) -> Bool {
        lhs.id == rhs.id && lhs.object == rhs.object && lhs.provider == rhs.provider && lhs.created == rhs.created
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
