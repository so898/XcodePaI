//
//  LLMConfig.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/26.
//

import Foundation

class LLMConfig: Identifiable, Codable {
    let id: UUID
    
    let name: String
    var modelProvider: String
    var modelName: String
    var mcps = [String]()
    
    enum CodingKeys: CodingKey {
        case id
        case modelProvider
        case name
        case modelName
        case mcps
    }
    
    init(id: UUID = UUID(), name: String, modelProvider: String, modelName: String, mcps: [String] = [String]()) {
        self.id = id
        self.name = name
        self.modelProvider = modelProvider
        self.modelName = modelName
        self.mcps = mcps
    }
    
    // MARK: - Codable
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        modelProvider = try container.decode(String.self, forKey: .modelProvider)
        modelName = try container.decode(String.self, forKey: .modelName)
        mcps = try container.decode([String].self, forKey: .mcps)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(modelProvider, forKey: .modelProvider)
        try container.encode(modelName, forKey: .modelName)
        try container.encode(mcps, forKey: .mcps)
    }
    
    func toChatProxyModel() -> ChatProxyLLMModel {
        return .init(id: name)
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
    
    func getTools() -> [LLMMCPTool] {
        var ret = [LLMMCPTool]()
        
        for mcp in mcps {
            ret.append(contentsOf: StorageManager.shared.toolsWithMCP(name: mcp))
        }
        
        return ret
    }
}
