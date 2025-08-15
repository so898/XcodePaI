//
//  LLMModel.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/9.
//

import Foundation
import Combine

typealias ChatProxyLLMModel = LLMModel

/// Represents an LLM model with observable properties
class LLMModel: Identifiable, ObservableObject, Codable {
    @Published var id: String
    var object: String = "model"  // Fixed value, no need for parameter
    var provider: String
    @Published var enabled: Bool
    let created: Int // Create Timestamp
    
    enum CodingKeys: String, CodingKey {
        case id
        case object
        case provider = "owned_by"  // Align with API key
        case enabled
        case created
    }
    
    // MARK: - Initializers
    init(
        id: String,
        provider: String,
        enabled: Bool = true,
        created: Int = Int(Date().timeIntervalSince1970)
    ) {
        self.id = id
        self.provider = provider
        self.enabled = enabled
        self.created = created
    }
    
    convenience init(
        id: String,
        created: Int = Int(Date().timeIntervalSince1970)
    ) {
        self.init(
            id: id,
            provider: Constraint.AppName,
            created: created
        )
    }
    
    /// Failable initializer from dictionary
    init?(_ dict: [String: Any], provider: String) {
        guard let id = dict["id"] as? String else {
            return nil
        }
        
        self.id = id
        self.provider = provider
        self.enabled = (dict["enabled"] as? Bool) ?? true
        self.created = (dict["created"] as? Int) ?? Int(Date().timeIntervalSince1970)
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
    
    // MARK: - Utilities
    public func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "object": object,
            "owned_by": provider,  // Consistent with CodingKeys
            "created": created
        ]
    }
}

// MARK: - Equatable & Hashable
extension LLMModel: Equatable, Hashable {
    static func == (lhs: LLMModel, rhs: LLMModel) -> Bool {
        lhs.id == rhs.id &&
        lhs.object == rhs.object &&
        lhs.provider == rhs.provider &&
        lhs.created == rhs.created &&
        lhs.enabled == rhs.enabled  // Include enabled state
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(object)
        hasher.combine(provider)
        hasher.combine(created)
        hasher.combine(enabled)
    }
}
