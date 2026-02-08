//
//  ChatProxySettingSectionView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/11.
//

import SwiftUI
import Combine

struct ChatProxySettingSectionView: View {
    @State private var portNumber = "\(Configer.chatProxyPort)"
    @State private var codeProxyConfigState = AgenticConfiger.checkCodexConfigState()
    @State private var enableThink = Configer.chatProxyEnableThink
    @State private var thinkStyle: Int = Configer.chatProxyThinkStyle.rawValue
    @State private var toolUseType: Int = Configer.chatProxyToolUseInRequest ? 0 : 1
    @State private var cutSourceInSearchRequest = Configer.chatProxyCutSourceInSearchRequest
    @State private var codeSnippetPreviewFix = Configer.chatProxyCodeSnippetPreviewFix
    @State private var quickWindowEnabled = Configer.chatProxyQuickWindow
    
    @State private var axPermissionGranted = Utils.checkAccessibilityPermission()
    
    @StateObject private var configManager = LLMConfigManager()
    
    @State private var isShowingSheet = false
    @State private var editConfig: LLMConfig?
    
    var body: some View {
        ScrollView {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 18) {
                
                // --- Chat Proxy Port ---
                GridRow(alignment: .center) {
                    Text("Local Server Port")
                    HStack(spacing: 10) {
                        TextField("", text: $portNumber)
                            .textFieldStyle(.plain)
                            .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                            .background(Color.black.opacity(0.3))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray))
                            .cornerRadius(5)
                            .frame(width: 80)
                            .onChange(of: portNumber) { _, newValue in
                                guard let value = UInt16(newValue) else {
                                    return
                                }
                                Configer.chatProxyPort = value
                            }
                        Button("Restart Server") {
                            ChatProxy.shared.restart()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                
                GridRow(alignment: .center) {
                    Text("Xcode Codex Proxy")
                    HStack(spacing: 10) {
                        if codeProxyConfigState == .configured {
                            Text(codeProxyConfigState.rawValue.localizedString)
                                .foregroundColor(.green)
                            Button("Open Codex Folder") {
                                NSWorkspace.shared.open(AgenticConfiger.CodexFolderURL)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        } else if codeProxyConfigState == .notInstalled {
                            Text(codeProxyConfigState.rawValue.localizedString)
                                .foregroundColor(.gray)
                        } else {
                            if codeProxyConfigState == .notConfigured || codeProxyConfigState == .misconfigured {
                                Text(codeProxyConfigState.rawValue.localizedString)
                                    .foregroundColor(.red)
                            }
                            Button("Configure Codex Proxy") {
                                AgenticConfiger.setupProxyConfig()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                    }
                }
                
                GridRow {
                    Divider().gridCellColumns(2)
                }
                
                GridRow(alignment: .center) {
                    Text("Enable Think")
                        .help("This switch turns on \"chain-of-thought\" reasoning, making the model explain its step-by-step thinking before answering — ideal for complex problems.")
                    Toggle("Enable", isOn: $enableThink)
                        .toggleStyle(.checkbox)
                        .onChange(of: enableThink) { _, newValue in
                            Configer.chatProxyEnableThink = newValue
                        }
                }
                
                GridRow(alignment: .center) {
                    Text("Show Think In")
                    Picker("", selection: $thinkStyle) {
                        Text("Code Snippet (Default)").tag(0)
                        Text("Text with EOT Mark").tag(1)
                        Text("In reasoning (not displayed)").tag(2)
                    }
                    .frame(maxWidth: 250, alignment: .leading)
                    .onChange(of: thinkStyle, { _, tag in
                        Configer.chatProxyThinkStyle = .init(rawValue: tag)!
                    })
                }
                
                GridRow(alignment: .top) {
                    Text("Tool Use")
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("", selection: $toolUseType) {
                            Text("In Request").tag(0)
                            Text("In System Prompt").tag(1)
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                        .onChange(of: toolUseType) { _, tag in
                            Configer.chatProxyToolUseInRequest = (tag == 0)
                        }
                        
                        Text("Some providers support tool use via request parameters.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                
                GridRow {
                    Text("Truncate source code in Xcode search results")
                        .help("To avoid exceeding the model's token limit with irrelevant code from Xcode's full-file search results, this feature intelligently condenses the source code surrounding the search keyword.")
                    Toggle("Enable", isOn: $cutSourceInSearchRequest)
                        .toggleStyle(.checkbox)
                        .onChange(of: cutSourceInSearchRequest) { _, newValue in
                            Configer.chatProxyCutSourceInSearchRequest = newValue
                        }
                }
                
                GridRow {
                    Text("Fix code snippet preview for Xcode 26.1.1 and later")
                        .help("A regression in Xcode 26.1.1 (and subsequent releases) prevents the code assistant from displaying previews for code snippets. The solution involves generating a virtual file name for each snippet; this name serves as the preview content within the interface.")
                    Toggle("Enable", isOn: $codeSnippetPreviewFix)
                        .toggleStyle(.checkbox)
                        .onChange(of: codeSnippetPreviewFix) { _, newValue in
                            Configer.chatProxyCodeSnippetPreviewFix = newValue
                        }
                }
                
                GridRow {
                    HStack(spacing: 3) {
                        Text("Quick Window")
                            .help("The Quick Window is a floating panel that appears below the text input field in Xcode's code assistant. It allows users to switch the model used by ChatProxy or to enable/disable MCP during an ongoing or new conversation. This feature requires Accessibility permissions.")
                        Image(systemName: "flask.fill")
                            .foregroundStyle(.blue)
                            .help("Experimental Feature")
                    }
                    Toggle("Enable", isOn: $quickWindowEnabled)
                        .disabled(!axPermissionGranted)
                        .toggleStyle(.checkbox)
                        .onChange(of: quickWindowEnabled) { _, newValue in
                            Configer.chatProxyQuickWindow = newValue
                        }
                }
            }
            .gridColumnAlignment(.trailing)
            .padding(30)
            
            Divider().padding(.leading)
            
            Form {
                CustomChatProxyConfigInfoSection()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                
                Section {
                    ForEach(configManager.configs) { config in
                        CustomChatProxyConfigRow(config: config) {
                            editConfig = config
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            
            HStack {
                Spacer()
                Button("Add custom config…") {
                    editConfig = nil
                    isShowingSheet = true
                }
                .controlSize(.large)
                .padding(.init(top: 0, leading: 0, bottom: 0, trailing: 16))
            }
            
            Spacer(minLength: 20)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle("Chat Proxy".localizedString)
        .sheet(isPresented: $isShowingSheet) {
            ChatProxyEditView(config: nil) { config in
                configManager.addConfig(config)
            } removeConfig: { config in
                configManager.deleteConfig(config)
            }
        }
        .sheet(item: $editConfig) { config in
            ChatProxyEditView(config: config) { config in
                configManager.addOrUpdateConfig(config)
            } removeConfig: { config in
                configManager.deleteConfig(config)
            }
        }
    }
}

struct CustomChatProxyConfigInfoSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: [.init(nsColor: .lightGray), .init(nsColor: .darkGray)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "bookmark.square").font(.system(size: 32)).foregroundColor(.white)
                }
                .frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom Config").font(.headline)
                    Text("Save custom configurations for your selected model and MCPs, and effortlessly access them in the Xcode Chat window.").font(.subheadline).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct CustomChatProxyConfigRow: View {
    @ObservedObject var config: LLMConfig
    var editConfigAction: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            CustomChatProxyConfigIconView(config: config, size: 24)
            Text(config.name)
            Spacer()
            if config !== StorageManager.shared.defaultConfig() {
                Button(action: {
                    editConfigAction()
                }) {
                    Image(systemName: "pencil")
                        .frame(width: 10, height: 10)
                }
                .buttonStyle(GetButtonStyle())
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }
}

struct CustomChatProxyConfigIconView: View {
    @ObservedObject var config: LLMConfig
    let size: CGFloat
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                .fill(Color.blue.opacity(0.7))
            Image(systemName: "text.book.closed")
                .resizable()
                .renderingMode(.template)
                .padding(4)
        }
        .frame(width: size, height: size)
    }
}
