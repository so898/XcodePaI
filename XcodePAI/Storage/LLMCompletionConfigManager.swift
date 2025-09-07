//
//  LLMCompletionConfigManager.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/9/7.
//

import Foundation

class LLMCompletionConfigManager: ObservableObject {
    @Published var configs: [LLMCompletionConfig] = []
    
    init() {
        loadInitialValue()
    }
    
    private func loadInitialValue() {
        configs = StorageManager.shared.completionConfigs
    }
    
    func addConfig(_ config: LLMCompletionConfig) {
        var currentConfigs = configs
        currentConfigs.append(config)
        saveConfigs(currentConfigs)
    }
    
    func addOrUpdateConfig(_ config: LLMCompletionConfig) {
        var currentConfigs = configs
        if let index = currentConfigs.firstIndex(where: { $0.id == config.id }) {
            currentConfigs[index] = config
            saveConfigs(currentConfigs)
        } else {
            currentConfigs.append(config)
            saveConfigs(currentConfigs)
        }
    }
    
    func deleteConfig(_ config: LLMCompletionConfig) {
        var currentConfigs = configs
        if let index = currentConfigs.firstIndex(where: { $0.id == config.id }) {
            currentConfigs.remove(at: index)
            saveConfigs(currentConfigs)
        }
    }
    
    private func saveConfigs(_ configs: [LLMCompletionConfig]) {
        self.configs = configs
        StorageManager.shared.updateCompletionConfigs(configs)
    }
}
