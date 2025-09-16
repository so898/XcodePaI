//
//  ModelProviderEditView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 8/13/25.
//

import SwiftUI

struct ModelProviderEditView: View {
    
    let currentProvider: LLMModelProvider?
    
    var createOrUpdateProvider: (LLMModelProvider) -> Void
    
    var removeProvider: ((LLMModelProvider) -> Void)?
    
    @State private var iconName: String = "ollama"
    @State private var url: String = ""
    @State private var apiKey: String = ""
    @State private var keyHeader: String = ""
    @State private var name: String = ""
    @State private var customModelsUrl: String = ""
    @State private var customChatUrl: String = ""
    @State private var customCompletionUrl: String = ""
    @State private var customUrls: Bool = false
    
    @State private var showIconList = false

    // Close Sheet
    @Environment(\.dismiss) var dismiss
    
    init(currentProvider: LLMModelProvider?, createOrUpdateProvider: @escaping (LLMModelProvider) -> Void, removeProvider: ((LLMModelProvider) -> Void)? = nil) {
        self.currentProvider = currentProvider
        self.createOrUpdateProvider = createOrUpdateProvider
        if let currentProvider = currentProvider {
            _iconName = State(initialValue: currentProvider.iconName)
            _url = State(initialValue: currentProvider.url)
            _apiKey = State(initialValue: currentProvider.privateKey ?? "")
            _keyHeader = State(initialValue: currentProvider.authHeaderKey ?? "")
            _name = State(initialValue: currentProvider.name)
            _customModelsUrl = State(initialValue: currentProvider.customModelsUrl ?? "")
            _customChatUrl = State(initialValue: currentProvider.customChatUrl ?? "")
            _customCompletionUrl = State(initialValue: currentProvider.customCompletionUrl ?? "")
        }
        _customUrls = State(initialValue: !customModelsUrl.isEmpty || !customChatUrl.isEmpty || !customCompletionUrl.isEmpty)
        self.removeProvider = removeProvider
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
            ZStack(alignment: .center){
                Image(iconName)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                HStack{
                    Spacer()
                    VStack{
                        Spacer()
                        Button {
                            // Change Icon Action
                            showIconList = true
                        } label: {
                            Image(systemName: "righttriangle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.init(top: 0, leading: 0, bottom: 8, trailing: 8))
                }
            }
            .background(Color.blue.opacity(0.7))
            .cornerRadius(10)
            .frame(width: 64, height: 64)
            .popover(isPresented: $showIconList) {
                ModelProviderIconListView(isPresented: $showIconList, choosedIconName: $iconName)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(currentProvider?.name ?? "Add a Model Provider".localizedString)
                    .font(.headline)
                    .fontWeight(.bold)
                Text(currentProvider != nil ? "Internet hosted model provider".localizedString : "Enter the information for the provider.".localizedString)
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
                FormFieldRow(label: "URL".localizedString, content: {
                    TextField("https://model.example.com".localizedString, text: $url)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                })
            }
            .background(Color.black.opacity(0.25))
            .cornerRadius(12)

            VStack(spacing: 0) {
                FormFieldRow(label: "API Key Header".localizedString, content: {
                    TextField("Header Key (Optional)".localizedString, text: $keyHeader)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                })
                
                Divider().padding(.leading)
                
                FormFieldRow(label: "API Key".localizedString, content: {
                    SecureField("Enter API Key".localizedString, text: $apiKey)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                })
            }
            .background(Color.black.opacity(0.25))
            .cornerRadius(12)
            
            VStack(spacing: 0) {
                FormFieldRow(label: "Custom URL".localizedString, content: {
                    Spacer()
                    Toggle("", isOn: $customUrls)
                        .toggleStyle(.switch)
                        .labelsHidden()
                })
                                
                if customUrls {
                    
                    Divider().padding(.leading)
                    
                    FormFieldRow(label: "Models URL".localizedString, content: {
                        TextField("/v1/models".localizedString, text: $customModelsUrl)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    })
                    
                    FormFieldRow(label: "Chat URL".localizedString, content: {
                        TextField("/v1/chat/completions".localizedString, text: $customChatUrl)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    })
                    
                    FormFieldRow(label: "Completion URL".localizedString, content: {
                        TextField("/v1/completions".localizedString, text: $customCompletionUrl)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    })
                }
            }
            .background(Color.black.opacity(0.25))
            .cornerRadius(12)
        }
    }

    private var buttonsSection: some View {
        HStack {
            if currentProvider != nil {
                Button(role: .destructive) {
                    if let currentProvider = currentProvider, let removeProvider = removeProvider {
                        removeProvider(currentProvider)
                    }
                    dismiss()
                } label: {
                    Text("Delete Provider".localizedString)
                        .frame(maxWidth: .infinity)
                }
                .tint(Color.red.opacity(0.7))
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: 200)
            }
            
            Spacer()

            Button("Cancel".localizedString) {
                dismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)


            Button("Save".localizedString) {
                // Do the check
                
                createOrUpdateProvider(
                    LLMModelProvider(
                        id: currentProvider?.id ?? UUID(),
                        name: name,
                        iconName: iconName,
                        url: url,
                        authHeaderKey: keyHeader.isEmpty ? nil : keyHeader,
                        privateKey: apiKey,
                        enabled: currentProvider?.enabled ?? true,
                        customModelsUrl: customModelsUrl.isEmpty ? nil : customModelsUrl,
                        customChatUrl: customChatUrl.isEmpty ? nil : customChatUrl,
                        customCompletionUrl: customCompletionUrl.isEmpty ? nil : customCompletionUrl
                    )
                )
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(url.isEmpty || name.isEmpty)
        }
    }
}
