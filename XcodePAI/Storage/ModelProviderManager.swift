//
//  ModelProviderManager.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/16.
//

import Foundation

class ModelProviderManager: ObservableObject {
    
    @Published private(set) var providers: [LLMModelProvider] = []
    
    init() {
        loadInitialValue()
    }
    
    private func loadInitialValue() {
        self.providers = StorageManager.shared.modelProviders
    }
    
    func addModelProvider(_ provider: LLMModelProvider) {
        var currentProviders = providers
        currentProviders.append(provider)
        saveModelProviders(currentProviders)
    }
    
    func updateModelProvider(_ provider: LLMModelProvider) {
        var currentProviders = providers
        if let index = currentProviders.firstIndex(where: { $0.id == provider.id }) {
            currentProviders[index] = provider
            saveModelProviders(currentProviders)
        }
    }
    
    func deleteModelProvider(_ provider: LLMModelProvider) {
        var currentProviders = providers
        if let index = currentProviders.firstIndex(where: { $0.id == provider.id }) {
            currentProviders.remove(at: index)
            saveModelProviders(currentProviders)
        }
    }
    
    private func saveModelProviders(_ providers: [LLMModelProvider]) {
        self.providers = providers
        StorageManager.shared.updateModelProviders(providers)
    }
}
