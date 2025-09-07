//
//  CompletionEditView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/9/7.
//

import SwiftUI

struct CompletionEditView: View {
    
    let currentConfig: LLMCompletionConfig?
    
    var createOrUpdateConfig: (LLMCompletionConfig) -> Void
    
    var removeConfig: ((LLMCompletionConfig) -> Void)
    
    @State private var name: String = ""
    @State private var model: String = ""
    @State private var type: LLMCompletionConfigType = .prefixSuffix
    
    @State var inPrompt: Bool = false
    @State var hasSuffix: Bool = false
    @State var maxTokens: String = ""
    
    @State private var headers = [KVObject]()
    
    // Close Sheet
    @Environment(\.dismiss) var dismiss
    
    init(config: LLMCompletionConfig?, createOrUpdateConfig: @escaping (LLMCompletionConfig) -> Void, removeConfig: @escaping ((LLMCompletionConfig) -> Void)) {
        self.currentConfig = config
        self.createOrUpdateConfig = createOrUpdateConfig
        if let config = config {
            _name = State(initialValue: config.name)
            _model = State(initialValue: "\(config.modelName)+\(config.modelProvider)")
            _type = State(initialValue: config.type)
            _inPrompt = State(initialValue: config.inPrompt)
            _hasSuffix = State(initialValue: config.hasSuffix)
            if let maxTokens = config.maxTokens {
                _maxTokens = State(initialValue: "\(maxTokens)")
            }
            
            if let headers = config.headers {
                var objects = [KVObject]()
                for key in headers.keys {
                    if let value = headers[key] {
                        objects.append(KVObject(key: key, value: value))
                    }
                }
                _headers = State(initialValue: objects)
            }
        }
        self.removeConfig = removeConfig
    }
    
    var body: some View {
        ZStack {
            Color(red: 30/255, green: 30/255, blue: 33/255).edgesIgnoringSafeArea(.all)
            
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
                Image(systemName: "keyboard.badge.ellipsis").font(.system(size: 24)).foregroundColor(.white)
            }
            .cornerRadius(10)
            .frame(width: 64, height: 64)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(currentConfig?.name ?? "Add a custom config")
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
                FormFieldRow(label: "Name", content: {
                    TextField("Name", text: $name)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                })
            }
            .background(Color.black.opacity(0.25))
            .cornerRadius(12)
            
            VStack(spacing: 0) {
                FormFieldRow(label: "Model", content: {
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
            
            Picker("", selection: $type) {
                Text("Prefix Request").tag(LLMCompletionConfigType.prefixSuffix)
                Text("Partial Request").tag(LLMCompletionConfigType.partial)
            }.pickerStyle(SegmentedPickerStyle())
                .padding()
            
            VStack(spacing: 8) {
                if type == .prefixSuffix {
                    FormFieldRow(label: "OpenAI format request", content: {
                        Spacer()
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("", isOn: $inPrompt)
                                .toggleStyle(.checkbox)
                            
                        }
                    })
                    FormFieldRow(label: "Allow suffix", content: {
                        Spacer()
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("", isOn: $hasSuffix)
                                .toggleStyle(.checkbox)
                            
                        }
                    })
                } else if type == .partial {
                    FormFieldRow(label: "Max Token", content: {
                        TextField("Max Token", text: $maxTokens)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    })
                }
            }
            .background(Color.black.opacity(0.25))
            .cornerRadius(12)
            
            VStack(spacing: 0) {
                
                ForEach ($headers) { header in
                    FormKVFieldRow {
                        TextField("Header Key", text: header.key)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.leading)
                    } value: {
                        TextField("Header Value", text: header.value)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    } deleteAction: {
                        if let index = headers.firstIndex(where: { $0.id == header.id }) {
                            headers.remove(at: index)
                        }
                    }
                    
                    Divider().padding(.leading)
                }
                
                HStack {
                    Spacer()
                    Button {
                        headers.append(KVObject(key: "", value: ""))
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 20, height: 20)
                        Text("Add Header")
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
                
            }
            .background(Color.black.opacity(0.25))
            .cornerRadius(12)
        }
    }
    
    @State private var isShowingTestPopover = false
    @State private var isRunningTest = false
    @State private var testPopoverContent = ""
    
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
                }
                .tint(Color.red.opacity(0.7))
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            
            Button(role: .destructive) {
                testPopoverContent = ""
                guard let config = buildConfig() else {
                    return
                }
                
                Task {
                    isRunningTest = true
                    testPopoverContent = await SuggestionTester.run(config) ?? "Test Fail"
                    isRunningTest = false
                    isShowingTestPopover = true
                }
            } label: {
                Text("Test Config")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(model.isEmpty || name.isEmpty || isRunningTest)
            .popover(
                isPresented: $isShowingTestPopover, arrowEdge: .bottom
            ) {
                Text(testPopoverContent)
                    .padding()
            }
            
            Spacer()
            
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            
            
            Button("Save") {
                guard let config = buildConfig() else {
                    return
                }
                createOrUpdateConfig(config)
                
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.isEmpty || name.isEmpty)
        }
    }
    
    private func buildConfig() -> LLMCompletionConfig? {
        let modelValues = model.components(separatedBy: "+")
        guard modelValues.count == 2 else {
            return nil
        }
        
        let modelName = modelValues[0]
        let modelProvider = modelValues[1]
        
        var headers = [String: String]()
        for header in self.headers {
            headers[header.key] = header.value
        }
        
        let newConfig = LLMCompletionConfig(id: currentConfig?.id ?? UUID(), name: name, modelProvider: modelProvider, modelName: modelName, type: type, inPrompt: inPrompt, hasSuffix: hasSuffix, maxTokens: Int(maxTokens), headers: headers)
        
        return newConfig
    }
    
}
