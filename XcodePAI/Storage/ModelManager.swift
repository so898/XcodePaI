//
//  ModelManager.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/16.
//

import Foundation

class ModelManager: ObservableObject {
    var storageKey: String
    
    @Published var models: [LLMModel] = []
    
    init(_ provider: String) {
        storageKey = provider
        loadInitialValue()
    }
    
    private func loadInitialValue() {
        models = StorageManager.shared.modelsWithProvider(name: storageKey)
    }
    
    func loadModels(_ provider: LLMModelProvider, complete: ((Bool) -> Void)?) {
        LLMModelClient.getModelsList(provider) {[weak self] models, error in
            if let models = models {
                DispatchQueue.main.async {[weak self] in
                    self?.replaceModels(models)
                    
                    complete?(true)
                }
                return
            }
            DispatchQueue.main.async {
                complete?(false)
            }
        }
    }
    
    func changeName(_ provider: String) {
        guard provider != storageKey else {
            return
        }
        StorageManager.shared.renameModels(from: storageKey, to: provider)
        storageKey = provider
        
        var newModels = [LLMModel]()
        for model in models {
            let newModel = model
            newModel.provider = provider
            newModels.append(newModel)
        }
        saveModels(newModels)
    }
    
    func addModel(_ model: LLMModel) {
        var currentModels = models
        currentModels.append(model)
        saveModels(currentModels)
    }
    
    func replaceModels(_ models: [LLMModel]) {
        let oldModels = StorageManager.shared.modelsWithProvider(name: storageKey)
        var newModels = [LLMModel]()
        for model in models {
            for oldModel in oldModels {
                if oldModel.id == model.id {
                    model.enabled = oldModel.enabled
                }
            }
            newModels.append(model)
        }
        saveModels(newModels)
    }
    
    func updateModel(_ model: LLMModel) {
        var currentModels = models
        if let index = currentModels.firstIndex(where: { $0.id == model.id }) {
            currentModels[index] = model
            saveModels(currentModels)
        }
    }
    
    func deleteModel(_ model: LLMModel) {
        var currentModels = models
        if let index = currentModels.firstIndex(where: { $0.id == model.id }) {
            currentModels.remove(at: index)
            saveModels(currentModels)
        }
    }
    
    private func saveModels(_ models: [LLMModel]) {
        self.models = models
        StorageManager.shared.updateModels(models, providerName: storageKey)
    }
}
