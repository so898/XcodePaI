//
//  LLMCompletionConfig.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/9/7.
//

import Foundation
import SuggestionPortal

enum LLMCompletionConfigType: Int {
    case prefixSuffix = 1
    case partial = 2
}

class LLMCompletionConfig: Identifiable, Codable, ObservableObject {
    let id: UUID
    
    let name: String
    var modelProvider: String
    var modelName: String
    
    var type: LLMCompletionConfigType

    // For PrefixSuffic
    var inPrompt: Bool
    var hasSuffix: Bool
    
    // For Partial
    var maxTokens: Int?
    
    var headers: [String: String]?
    
    enum CodingKeys: CodingKey {
        case id
        case modelProvider
        case name
        case modelName
        case type
        case inPrompt
        case hasSuffix
        case maxTokens
        case headers
    }
    
    init(id: UUID = UUID(), name: String, modelProvider: String, modelName: String, type: LLMCompletionConfigType, inPrompt: Bool = false, hasSuffix: Bool = false, maxTokens: Int? = nil, headers: [String: String]? = nil) {
        self.id = id
        self.name = name
        self.modelProvider = modelProvider
        self.modelName = modelName
        self.type = type
        self.inPrompt = inPrompt
        self.hasSuffix = hasSuffix
        self.maxTokens = maxTokens
        self.headers = headers
    }
    
    // MARK: - Codable
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        modelProvider = try container.decode(String.self, forKey: .modelProvider)
        modelName = try container.decode(String.self, forKey: .modelName)
        type = LLMCompletionConfigType(rawValue: try container.decode(Int.self, forKey: .type)) ?? .prefixSuffix
        inPrompt = try container.decode(Bool.self, forKey: .inPrompt)
        hasSuffix = try container.decode(Bool.self, forKey: .hasSuffix)
        maxTokens = try container.decodeIfPresent(Int.self, forKey: .maxTokens)
        headers = try container.decodeIfPresent([String: String].self, forKey: .headers)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(modelProvider, forKey: .modelProvider)
        try container.encode(modelName, forKey: .modelName)
        try container.encode(type.rawValue, forKey: .type)
        try container.encode(inPrompt, forKey: .inPrompt)
        try container.encode(hasSuffix, forKey: .hasSuffix)
        try container.encodeIfPresent(maxTokens, forKey: .maxTokens)
        try container.encodeIfPresent(headers, forKey: .headers)
    }
    
    func getModelProvider() -> LLMModelProvider? {
        for provider in StorageManager.shared.modelProviders {
            if provider.name == modelProvider {
                return provider
            }
        }
        return nil
    }
    
    func getModel() -> LLMModel? {
        for model in StorageManager.shared.models {
            if model.id == modelName, model.provider == modelProvider {
                return model
            }
        }
        return nil
    }
    
    func getSuggestion() -> SuggestionPortalProtocol? {
        var suggestion: SuggestionPortalProtocol?
        guard let provider = getModelProvider(), let model = getModel() else {
            return suggestion
        }
        switch type {
        case .prefixSuffix:
            suggestion = PrefixSuffixSuggestion(model: model, provider: provider, inPrompt: inPrompt, hasSuffix: hasSuffix)
        case .partial:
            suggestion = PartialSuggestion(model: model, provider: provider, maxTokens: maxTokens)
        }
        return suggestion
    }
}
