//
//  ModelProviderManager.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/16.
//

import Combine

class ModelProviderManager: ObservableObject {
    static let storageKey = Constraint.modelProviderStorageKey
    
    @Published private(set) var providers: [LLMModelProvider] = []
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadInitialValue()
    }
    
    private func loadInitialValue() {
        LocalStorage.shared.fetch(forKey: Self.storageKey)
            .replaceNil(with: [])
            .assign(to: \.providers, on: self)
            .store(in: &cancellables)
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
        LocalStorage.shared.save(providers, forKey: Self.storageKey)
            .sink { _ in }
            .store(in: &cancellables)
    }
}
