//
//  ModelManager.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/16.
//

import Combine
import Foundation

class ModelManager: ObservableObject {
    var storageKey: String
    
    @Published var models: [LLMModel] = []
    private var cancellables = Set<AnyCancellable>()
    
    init(_ provider: String) {
        storageKey = Constraint.modelStorageKeyPrefix + provider
        loadInitialValue()
    }
    
    private func loadInitialValue() {
        LocalStorage.shared.fetch(forKey: storageKey)
            .replaceNil(with: [])
            .assign(to: \.models, on: self)
            .store(in: &cancellables)
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
        let newStorageKey = "LLMModelStorage_" + provider
        guard newStorageKey != storageKey else {
            return
        }
        LocalStorage.shared.renameStorage(oldKey: storageKey, newKey: newStorageKey)
        storageKey = newStorageKey
        
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
        self.models = models
        saveModels(models)
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
        LocalStorage.shared.save(models, forKey: storageKey)
            .sink { _ in }
            .store(in: &cancellables)
    }
}
