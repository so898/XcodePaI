//
//  ProviderModelRefresher.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/12/14.
//

struct ProviderModelRefresher {
    static let shared = ProviderModelRefresher()
    
    func refreshAllProviderModels() {
        Task {
            let providers = StorageManager.shared.modelProviders
            for provider in providers {
                do {
                    try await refreshModels(provider)
                } catch {
                    print("Provider \(provider.name) update model list fail.")
                }
            }
        }
    }
    
    private func refreshModels(_ provider: LLMModelProvider) async throws {
        let models = try await LLMModelClient.getModelsList(provider)
        let oldModels = StorageManager.shared.modelsWithProvider(name: provider.name)
        var newModels = [LLMModel]()
        for model in models {
            for oldModel in oldModels {
                if oldModel.id == model.id {
                    model.enabled = oldModel.enabled
                }
            }
            newModels.append(model)
        }
        StorageManager.shared.updateModels(newModels, providerName: provider.name)
    }
}
