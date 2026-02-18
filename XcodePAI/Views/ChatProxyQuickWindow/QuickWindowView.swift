//
//  QuickWindowView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/12/21.
//

import SwiftUI

struct QuickWindowView: View {
    @StateObject private var dataManager = QuickWindowDataManager()
    @StateObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        VStack{
            Spacer()
            HStack(spacing: 5) {
                Menu {
                    ForEach(dataManager.availableProviderNames, id: \.self) { providerName in
                        Menu(providerName) {
                            if let models = dataManager.availableModelDic[providerName] {
                                ForEach(models, id: \.id) { model in
                                    Button(action: {
                                        selectModel(model.id, provider: model.provider)
                                    }) {
                                        if let id = dataManager.defaultCofig?.modelName, id == model.id {
                                            Label(model.id, systemImage: "checkmark")
                                        } else {
                                            Label(model.id, systemImage: "")
                                        }
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    Text(dataManager.defaultCofig?.modelName ?? "Unset")
                        .foregroundColor(Color(nsColor: .textColor))
                }
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(.capsule)
                .frame(height: 19)
                
                if !dataManager.availableMCPs.isEmpty {
                    Menu {
                        ForEach(dataManager.availableMCPs, id: \.id) { mcp in
                            Button(action: {
                                selectMCP(mcp.name)
                            }) {
                                if let mcps = dataManager.defaultCofig?.mcps, mcps.contains(mcp.name) {
                                    Label(mcp.name, systemImage: "checkmark")
                                } else {
                                    Label(mcp.name, systemImage: "")
                                }
                            }
                        }
                    } label: {
                        Text("MCP")
                            .foregroundColor((dataManager.defaultCofig?.mcps.isEmpty ?? true) ? Color(nsColor: .textColor) : Color.white)
                    }
                    .background((dataManager.defaultCofig?.mcps.isEmpty ?? true) ? Color(nsColor: .textBackgroundColor) : Color(nsColor: .selectedContentBackgroundColor))
                    .clipShape(.capsule)
                    .frame(height: 19)
                }
            }
            Spacer()
        }
        .frame(height: QuickWindowHeight)
        .environment(\.locale, languageManager.currentLanguage == nil ? .current : .init(identifier: languageManager.currentLanguage!))
    }
    
    private func selectModel(_ id: String, provider: String) {
        if let config = StorageManager.shared.defaultConfig(),
           let models = dataManager.availableModelDic[provider],
           let model = models.first(where: { m in
               m.id == id
           }) {
            config.modelName = model.id
            config.modelProvider = model.provider
            StorageManager.shared.updateDefaultConfig(config)
        }
    }
    
    private func selectMCP(_ mcpName: String) {
        if let config = StorageManager.shared.defaultConfig() {
            if config.mcps.contains(mcpName) {
                config.mcps.removeAll { name in
                    name == mcpName
                }
            } else {
                config.mcps.append(mcpName)
            }
            StorageManager.shared.updateDefaultConfig(config)
            MCPServer.shared.updateTools(config.getTools())
        }
    }
}

class QuickWindowDataManager: ObservableObject {
    @Published private(set) var defaultCofig: LLMConfig?
    @Published private(set) var availableProviderNames: [String] = []
    @Published private(set) var availableModelDic: [String: [LLMModel]] = [:]
    @Published private(set) var availableMCPs: [LLMMCP] = []
    
    init() {
        loadInitialValue()
    }
    
    private func loadInitialValue() {
        NotificationCenter.default.addObserver(self, selector: #selector(defaultConfigUpdated), name: .storageDefaultLLMUpdated, object: nil)
        defaultConfigUpdated()
        
        var modelDic = [String: [LLMModel]]()
        var lastProviderName = ""
        var models = [LLMModel]()
        for model in StorageManager.shared.availableModels() {
            if lastProviderName != model.provider {
                if !lastProviderName.isEmpty {
                    availableProviderNames.append(lastProviderName)
                    modelDic[lastProviderName] = models
                }
                lastProviderName = model.provider
                models = [LLMModel]()
            }
            
            models.append(model)
        }
        if !lastProviderName.isEmpty {
            availableProviderNames.append(lastProviderName)
            modelDic[lastProviderName] = models
        }
        
        availableModelDic = modelDic
    }
    
    @objc func defaultConfigUpdated() {
        defaultCofig = StorageManager.shared.defaultConfig()
        availableMCPs = StorageManager.shared.availableMCPs()
    }
}
