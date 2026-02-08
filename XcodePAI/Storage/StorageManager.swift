//
//  StorageManager.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/19.
//

import Foundation
import Combine


extension Notification.Name {
    static let storageDefaultLLMUpdated = Notification.Name("StorageDefaultLLMUpdated")
}

class StorageManager {
    static let shared = StorageManager()
    
    public var modelProviders = [LLMModelProvider]()
    public var models = [LLMModel]()
    public var mcps = [LLMMCP]()
    public var mcpTools = [LLMMCPTool]()
    
    public var llmConfigs = [LLMConfig]()
    
    public var completionConfigs = [LLMCompletionConfig]()
    
    private var cancellables = Set<AnyCancellable>()
    
    func load() async {
        modelProviders = await LocalStorage.shared.getValue(forKey: Constraint.modelProviderStorageKey) ?? [LLMModelProvider]()
        
        for modelProvider in modelProviders {
            if let thisModels: [LLMModel] = await LocalStorage.shared.getValue(forKey: Constraint.modelStorageKeyPrefix + modelProvider.name) {
                models.append(contentsOf: thisModels)
            }
        }
        
        mcps = await LocalStorage.shared.getValue(forKey: Constraint.mcpStorageKey) ?? [LLMMCP]()
        
        for mcp in mcps {
            if let thisTools: [LLMMCPTool] = await LocalStorage.shared.getValue(forKey: Constraint.mcpToolStorageKeyPrefix + mcp.name) {
                mcpTools.append(contentsOf: thisTools)
            }
        }
        
        llmConfigs = await LocalStorage.shared.getValue(forKey: Constraint.llmConfigStorageKey) ?? [LLMConfig]()
        
        completionConfigs = await LocalStorage.shared.getValue(forKey: Constraint.completionConfigStorageKey) ?? [LLMCompletionConfig]()
    }
}

// MARK: ModelProvider
extension StorageManager {
    func updateModelProviders(_ providers: [LLMModelProvider]) {
        modelProviders = providers
        LocalStorage.shared.save(providers, forKey: Constraint.modelProviderStorageKey)
            .sink { _ in }
            .store(in: &cancellables)
    }
}

// MARK: Model
extension StorageManager {
    func modelsWithProvider(name: String) -> [LLMModel] {
        var ret = [LLMModel]()
        for model in models {
            if model.provider == name {
                ret.append(model)
            }
        }
        return ret
    }
    
    func updateModels(_ models: [LLMModel], providerName: String) {
        self.models.removeAll { model in
            model.provider == providerName
        }
        self.models.append(contentsOf: models)
        LocalStorage.shared.save(models, forKey: Constraint.modelStorageKeyPrefix + providerName)
            .sink { _ in }
            .store(in: &cancellables)
    }
    
    func renameModels(from: String, to: String) {
        for model in models {
            if model.provider == from {
                model.provider = to
            }
        }
        LocalStorage.shared.renameStorage(oldKey: Constraint.modelStorageKeyPrefix + from, newKey: Constraint.modelStorageKeyPrefix + to)
    }
    
    func availableModels() -> [LLMModel] {
        var ret = [LLMModel]()
        for provider in modelProviders {
            guard provider.enabled else { continue }
            let models = modelsWithProvider(name: provider.name) .sorted { a, b in
                a.id < b.id
            }
            for model in models {
                if model.enabled {
                    ret.append(contentsOf: models)
                }
            }
        }
        return ret
    }
}

// MARK: MCP
extension StorageManager {
    func updateMCPs(_ mcps: [LLMMCP]) {
        self.mcps = mcps
        LocalStorage.shared.save(mcps, forKey: Constraint.mcpStorageKey)
            .sink { _ in }
            .store(in: &cancellables)
    }
    
    func availableMCPs() -> [LLMMCP] {
        var ret = [LLMMCP]()
        for mcp in mcps {
            if mcp.enabled {
                ret.append(mcp)
            }
        }
        return ret
    }
}

// MARK: MCP Tool
extension StorageManager {
    func toolsWithMCP(name: String) -> [LLMMCPTool] {
        var ret = [LLMMCPTool]()
        for tool in mcpTools {
            if tool.mcp == name {
                ret.append(tool)
            }
        }
        return ret
    }
    
    func updateMCPTools(_ tools: [LLMMCPTool], mcpName: String) {
        self.mcpTools.removeAll { tool in
            tool.mcp == mcpName
        }
        self.mcpTools.append(contentsOf: tools)
        LocalStorage.shared.save(tools, forKey: Constraint.mcpToolStorageKeyPrefix + mcpName)
            .sink { _ in }
            .store(in: &cancellables)
    }
    
    func renameTools(from: String, to: String) {
        for tool in mcpTools {
            if tool.mcp == from {
                tool.mcp = to
            }
        }
        LocalStorage.shared.renameStorage(oldKey: Constraint.mcpToolStorageKeyPrefix + from, newKey: Constraint.mcpToolStorageKeyPrefix + to)
    }
}

// MARK: LLM Config
extension StorageManager {
    func updateLLMConfigs(_ configs: [LLMConfig]) {
        llmConfigs = configs
        LocalStorage.shared.save(configs, forKey: Constraint.llmConfigStorageKey)
            .sink { _ in }
            .store(in: &cancellables)
    }
    
    func defaultConfig() -> LLMConfig? {
        for config in llmConfigs {
            if config.name == Constraint.AppName {
                return config
            }
        }
        
        if let model = models.first {
            let config = LLMConfig(name: Constraint.AppName, modelProvider: model.provider, modelName: model.id)
            updateDefaultConfig(config)
            return config
        }
        
        return nil
    }
    
    func updateDefaultConfig(_ config: LLMConfig) {
        llmConfigs.removeAll { config in
            config.name == Constraint.AppName
        }
        llmConfigs.append(config)
        updateLLMConfigs(llmConfigs)
        NotificationCenter.default.post(name: .storageDefaultLLMUpdated, object: nil)
    }
    
    func getChatProxyModels() -> [ChatProxyModel] {
        var ret = [ChatProxyModel]()
        
        if let defaultConfig = defaultConfig() {
            ret.append(defaultConfig.toChatProxyModel())
        }
        
        for config in llmConfigs {
            if config.name != Constraint.AppName {
                ret.append(config.toChatProxyModel())
            }
        }
        
        return ret
    }
    
    func getConfig(_ name: String) -> LLMConfig? {
        for llmConfig in llmConfigs {
            if llmConfig.name == name {
                return llmConfig
            }
        }
        return nil
    }
}

// MARK: Completion Config
extension StorageManager {
    func updateCompletionConfigs(_ configs: [LLMCompletionConfig]) {
        completionConfigs = configs
        LocalStorage.shared.save(configs, forKey: Constraint.completionConfigStorageKey)
            .sink { _ in }
            .store(in: &cancellables)
    }
    
    func selectedCompletionConfig() -> LLMCompletionConfig? {
        for config in completionConfigs {
            if config.id == Configer.completionSelectConfigId {
                return config
            }
        }
        
        if let config = completionConfigs.first {
            return config
        }
        
        return nil
    }
}
