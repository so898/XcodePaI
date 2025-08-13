//
//  ModelProviderDetailView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/13.
//

import SwiftUI
import Combine

class ModelManager: ObservableObject {
    var storageKey: String
    
    @Published var models: [LLMModel] = []
    private var cancellables = Set<AnyCancellable>()
    
    init(_ provider: String) {
        storageKey = "LLMModelStorage_" + provider
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

// MARK: - Provider Detail View
struct ModelProviderDetailView: View {
    @EnvironmentObject private var loadingState: LoadingState
    
    @ObservedObject var providerManager: ModelProviderManager
    @ObservedObject var modelManager: ModelManager
    
    @State private var provider: LLMModelProvider
        
    @State private var sortOrder = [KeyPathComparator(\LLMModel.id)]
        
    @State private var isShowingSheet = false
    @State private var isShowingNewModelSheet = false
    @State private var isShowingAlert = false
    @State private var isShowingSuccessAlert = false
    @State private var isReloadSuccess = false
    
    @Environment(\.dismiss) private var dismiss
    
    init(providerManager: ModelProviderManager, provider: LLMModelProvider) {
        self.providerManager = providerManager
        modelManager = ModelManager(provider.name)
        _provider = State(initialValue: provider)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ModelProviderDetailHeader(provider: provider, isEnabled: providerEnableToggleBinding(for: provider)) {
                isShowingSheet = true
            } refreshModelAction: {
                if modelManager.models.count > 0 {
                    isShowingAlert = true
                } else {
                    fetchModels()
                }
            }
            
            Divider()
            
            modelsTable
            
            ModelProviderDetailFooterActionsView {
                isShowingNewModelSheet = true
            }
        }
        .navigationTitle(provider.name)
        .sheet(isPresented: $isShowingSheet) {
            ModelProviderEditView(currentProvider: provider){ updatedProvider in
                self.provider = updatedProvider
                modelManager.changeName(updatedProvider.name)
                providerManager.updateModelProvider(updatedProvider)
            } removeProvider: { removeProvider in
                providerManager.deleteModelProvider(removeProvider)
                dismiss()
            }
        }
        .sheet(isPresented: $isShowingNewModelSheet, content: {
            ModelAddView { modelName in
                modelManager.addModel(LLMModel(id: modelName, provider: provider.name))
            }
        })
        .alert("Reload models will remove all exist model config.", isPresented: $isShowingAlert) {
            Button(role: .destructive) {
                fetchModels()
            } label: {
                Text("Reload")
            }
        }
        .alert(isReloadSuccess ? "Reload models success." : "Reload models fail.", isPresented: $isShowingSuccessAlert) {
        }
    }
    
    private func providerEnableToggleBinding(for provider: LLMModelProvider) -> Binding<Bool> {
        Binding<Bool>(
            get: { provider.enabled },
            set: { newValue in
                let newProvider = provider
                newProvider.enabled = newValue
                self.provider = newProvider
                providerManager.updateModelProvider(newProvider)
            }
        )
    }
    
    private func fetchModels() {
        LoadingState.shared.show(text: "Fetch Models...")
        modelManager.loadModels(provider) { success in
            isReloadSuccess = success
            isShowingSuccessAlert = true
            LoadingState.shared.hide()
        }
    }
    
    @State var showTestAlert = false
    @State var testResult = false
    private var modelsTable: some View {
        Table(modelManager.models, sortOrder: $sortOrder) {
            TableColumn("Identifier", value: \LLMModel.id) { model in
                HStack{
                    Text(model.id)
                    Spacer()
                }
                .contextMenu {
                    Button("Delete") {
                        modelManager.deleteModel(model)
                    }
                }
            }
            
            TableColumn("Action") { model in
                Button {
                    LoadingState.shared.show(text: "Testing...")
                    LLMModelClient.testModel(model, provider: provider) { ret in
                        LoadingState.shared.hide()
                        testResult = ret
                        showTestAlert = true
                    }
                } label: {
                    Text("Test")
                }
                .buttonStyle(GetButtonStyle())
                .alert(testResult ? "Test Success" : "Test Fail", isPresented: $showTestAlert) {
                }
            }
            .width(60)
            
            TableColumn("Enabled") { model in
                ToggleView(model: model, modelManager: modelManager)
            }
            .width(60)
        }
        .tableStyle(.inset)
        .onChange(of: sortOrder) {
            modelManager.models.sort(using: sortOrder)
        }
    }
}

// Helper View to break down complex expression
private struct ToggleView: View {
    let model: LLMModel
    @ObservedObject var modelManager: ModelManager // Replace with your manager's type
    
    var body: some View {
        HStack {
            Spacer()
            Toggle("", isOn: toggleBinding(for: model))
                .labelsHidden()
                .toggleStyle(.checkbox)
            Spacer()
        }
    }
    
    // Dedicated function for Binding creation
    private func toggleBinding(for model: LLMModel) -> Binding<Bool> {
        Binding<Bool>(
            get: { model.enabled },
            set: { newValue in
                let newModel = model
                newModel.enabled = newValue
                modelManager.updateModel(newModel)
            }
        )
    }
}

// MARK: - Reusable Subviews

struct ModelProviderDetailHeader: View {
    @ObservedObject var provider: LLMModelProvider
    @Binding var isEnabled: Bool
    var editProviderAction: () -> Void
    var refreshModelAction: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ModelProviderIconView(provider: provider, size: 40)
            Text(provider.name).font(.title2).fontWeight(.medium)
            
            Spacer()
            
            Button(action: {
                refreshModelAction()
            }) {
                Image(systemName: "arrow.trianglehead.clockwise")
                    .frame(width: 10, height: 10)
            }
            .buttonStyle(GetButtonStyle())
            
            Button(action: {
                editProviderAction()
            }) {
                Image(systemName: "pencil")
                    .frame(width: 10, height: 10)
            }
            .buttonStyle(GetButtonStyle())
            
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding()
    }
}

struct ModelProviderDetailFooterActionsView: View {
    var addButtonAction: (() -> Void)
    
    var body: some View {
        HStack {
            Button(action: {
                addButtonAction()
            }) {
                Image(systemName: "plus")
                    .frame(width: 20, height: 20)
            }
            Spacer()
        }
        .padding(8)
        .buttonStyle(.borderless) // Use borderless for icon-only buttons
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
