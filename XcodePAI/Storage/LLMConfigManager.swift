//
//  LLMConfigManager.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/9/1.
//

import Foundation

class LLMConfigManager: ObservableObject {
    @Published var configs: [LLMConfig] = []
    
    init() {
        loadInitialValue()
    }
    
    private func loadInitialValue() {
        configs = StorageManager.shared.llmConfigs
    }
    
    func addConfig(_ config: LLMConfig) {
        var currentConfigs = configs
        currentConfigs.append(config)
        saveConfigs(currentConfigs)
    }
    
    func addOrUpdateConfig(_ config: LLMConfig) {
        var currentConfigs = configs
        if let index = currentConfigs.firstIndex(where: { $0.id == config.id }) {
            currentConfigs[index] = config
            saveConfigs(currentConfigs)
        } else {
            currentConfigs.append(config)
            saveConfigs(currentConfigs)
        }
    }
    
    func deleteConfig(_ config: LLMConfig) {
        var currentConfigs = configs
        if let index = currentConfigs.firstIndex(where: { $0.id == config.id }) {
            currentConfigs.remove(at: index)
            saveConfigs(currentConfigs)
        }
    }
    
    private func saveConfigs(_ configs: [LLMConfig]) {
        self.configs = configs
        StorageManager.shared.updateLLMConfigs(configs)
    }
}
