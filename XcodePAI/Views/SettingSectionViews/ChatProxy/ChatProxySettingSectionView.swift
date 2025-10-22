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
    @State private var thinkStyle: Int = Configer.chatProxyThinkStyle.rawValue
    @State private var toolUseType: Int = Configer.chatProxyToolUseInRequest ? 0 : 1
    @State private var cutSourceInSearchRequest = Configer.chatProxyCutSourceInSearchRequest
    
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
                
                GridRow {
                    Divider().gridCellColumns(2)
                }
                
                GridRow(alignment: .center) {
                    Text("Show Think In")
                    Picker("", selection: $thinkStyle) {
                        Text("Code Snippet (Default)").tag(0)
                        Text("Text with EOT Mark").tag(1)
                        Text("In Reasoning (Not Display)").tag(2)
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
                            Text("In Reqeust").tag(0)
                            Text("In System Prompt").tag(1)
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                        .onChange(of: toolUseType) { _, tag in
                            Configer.chatProxyToolUseInRequest = (tag == 0)
                        }
                        
                        Text("Some provider support use tool with request parameters.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                
                GridRow {
                    Text("Cut source code in Xcode search result")
                    Toggle("Enable", isOn: $cutSourceInSearchRequest)
                        .toggleStyle(.checkbox)
                        .onChange(of: cutSourceInSearchRequest) { _, newValue in
                            Configer.chatProxyCutSourceInSearchRequest = newValue
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

struct  CustomChatProxyConfigIconView: View {
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
