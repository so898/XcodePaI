//
//  ChatProxyEditView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/27.
//

import SwiftUI

struct ChatProxyEditView: View {
    
    let currentConfig: LLMConfig?
    
    var createOrUpdateConfig: (LLMConfig) -> Void
    
    var removeConfig: ((LLMConfig) -> Void)
    
    @State private var name: String = ""
    @State private var model: String = ""
    @State private var mcps = [String]()
    
    // Close Sheet
    @Environment(\.dismiss) var dismiss
    
    init(config: LLMConfig?, createOrUpdateConfig: @escaping (LLMConfig) -> Void, removeConfig: @escaping ((LLMConfig) -> Void)) {
        self.currentConfig = config
        self.createOrUpdateConfig = createOrUpdateConfig
        if let config = config {
            _name = State(initialValue: config.name)
            _model = State(initialValue: "\(config.modelName)+\(config.modelProvider)")
            _mcps = State(initialValue: config.mcps)
        }
        self.removeConfig = removeConfig
    }
    
    var body: some View {
        ZStack {            
            VStack(alignment: .leading, spacing: 20) {
                headerView
                
                formSection
                
                Spacer()
                
                buttonsSection
            }
            .padding()
        }
    }
    
    // MARK: - subviews
    
    private var headerView: some View {
        HStack(spacing: 15) {
            ZStack {
                Color.black
                Image(systemName: "bookmark.square").font(.system(size: 24)).foregroundColor(.white)
            }
            .cornerRadius(10)
            .frame(width: 64, height: 64)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(currentConfig?.name ?? "Add a custom config".localizedString)
                    .font(.headline)
                    .fontWeight(.bold)
                Text(currentConfig != nil ? "Edit config" : "Enter the information for the config.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(8)
        .background(Color.black.opacity(0.25))
        .cornerRadius(12)
    }
    
    private var formSection: some View {
        VStack(spacing: 8) {
            VStack(spacing: 0) {
                FormFieldRow(label: "Name".localizedString, content: {
                    TextField("Name".localizedString, text: $name)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                })
            }
            .background(Color.black.opacity(0.25))
            .cornerRadius(12)
            
            VStack(spacing: 0) {
                FormFieldRow(label: "Model".localizedString, content: {
                    Spacer()
                    Picker("", selection: $model) {
                        let groupedModels = Dictionary(grouping: StorageManager.shared.models, by: \.provider)
                        
                        ForEach(groupedModels.keys.sorted(), id: \.self) { provider in
                            Section(header: VStack(alignment: .leading) {
                                Text(provider)
                                    .font(.headline)
                                    .padding(.top, 8)
                            }) {
                                ForEach(groupedModels[provider] ?? []) { model in
                                    Text(model.id)
                                        .tag("\(model.id)+\(model.provider)")
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 250, alignment: .leading)
                })
            }
            .background(Color.black.opacity(0.25))
            .cornerRadius(12)
            
            VStack(spacing: 0) {
                
                ForEach(mcps.indices, id: \.self) { index in
                    HStack {
                        Picker("", selection: $mcps[index]) {
                            ForEach(StorageManager.shared.mcps) { mcpService in
                                Text(mcpService.name)
                                    .tag(mcpService.name)
                                    .padding(.vertical, 4)
                            }
                        }
                        .frame(maxWidth: 250, alignment: .leading)
                        
                        Spacer()
                        Button {
                            if mcps.indices.contains(index) {
                                mcps.remove(at: index)
                            }
                        } label: {
                            Image(systemName: "minus")
                                .frame(width: 20, height: 20)
                                .foregroundColor(.white)
                                .background(Color.red)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                }
                
                HStack {
                    Spacer()
                    Button {
                        mcps.append("")
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 20, height: 20)
                        Text("Add MCP")
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
                
            }
            .background(Color.black.opacity(0.25))
            .cornerRadius(12)
        }
    }
    
    private var buttonsSection: some View {
        HStack {
            if currentConfig != nil {
                Button(role: .destructive) {
                    if let currentConfig = currentConfig {
                        removeConfig(currentConfig)
                    }
                    dismiss()
                } label: {
                    Text("Delete Config")
                        .frame(maxWidth: .infinity)
                }
                .tint(Color.red.opacity(0.7))
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: 200)
            }
            
            Spacer()
            
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            
            
            Button("Save") {
                
                let modelValues = model.components(separatedBy: "+")
                guard modelValues.count == 2 else {
                    return
                }
                
                let modelName = modelValues[0]
                let modelProvider = modelValues[1]
                
                let newConfig = LLMConfig(id: currentConfig?.id ?? UUID(), name: name, modelProvider: modelProvider, modelName: modelName, mcps: mcps)
                
                createOrUpdateConfig(newConfig)
                
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.isEmpty || name.isEmpty)
        }
    }
    
}
