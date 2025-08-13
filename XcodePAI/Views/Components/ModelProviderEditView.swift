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
        }
        self.removeProvider = removeProvider
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
                Text(currentProvider?.name ?? "Add a Model Provider")
                    .font(.headline)
                    .fontWeight(.bold)
                Text(currentProvider != nil ? "Internet hosted model provider" : "Enter the information for the provider.")
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
                FormFieldRow(label: "URL", content: {
                    TextField("https://model.example.com", text: $url)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                })
            }
            .background(Color.black.opacity(0.25))
            .cornerRadius(12)

            VStack(spacing: 0) {
                FormFieldRow(label: "API Key Header", content: {
                    TextField("Header Key (Optional)", text: $keyHeader)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                })
                
                Divider().padding(.leading)
                
                FormFieldRow(label: "API Key", content: {
                    SecureField("Enter API Key", text: $apiKey)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                })
            }
            .background(Color.black.opacity(0.25))
            .cornerRadius(12)
            
            VStack(spacing: 0) {
                FormFieldRow(label: "Description", content: {
                    TextField("Name", text: $name)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                })
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
                    Text("Delete Provider")
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
                // Do the check
                
                createOrUpdateProvider(LLMModelProvider(id: currentProvider?.id ?? UUID(), name: name, iconName: iconName, url: url, authHeaderKey: keyHeader.isEmpty ? nil : keyHeader, privateKey: apiKey))
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .controlSize(.large)
            .disabled(url.isEmpty || name.isEmpty)
        }
    }
}


// MARK: - From File Components

private struct FormFieldRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            content
                .foregroundColor(.primary)
        }
        .padding(16)
    }
}

private struct InfoRow: View {
    let label: String
    @Binding var value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
        .padding()
    }
}
