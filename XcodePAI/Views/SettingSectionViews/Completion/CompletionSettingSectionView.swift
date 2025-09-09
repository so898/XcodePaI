//
//  CompletionSettingSectionView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/9/6.
//

import SwiftUI
import Combine
import Status

struct CompletionSettingSectionView: View {
    @AppStorage(\.realtimeSuggestionToggle) var realtimeSuggestionToggle
    @State private var axPermissionGranted = Utils.checkAccessibilityPermission()
    @State private var extensionPermissionStatus = Status.shared.getExtensionStatus()
    @AppStorage(\.acceptSuggestionWithTab) var acceptSuggestionWithTab
    @AppStorage(\.realtimeSuggestionDebounce) var realtimeSuggestionDebounce
    @State var isSuggestionFeatureDisabledLanguageListViewOpen = false
    
    @StateObject private var configManager = LLMCompletionConfigManager()
    
    @State private var isShowingSheet = false
    @State private var editConfig: LLMCompletionConfig?
    
    var body: some View {
        ScrollView {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 18) {
                
                GridRow(alignment: .center) {
                    Text("Realtime Suggestion")
                    Toggle("Enable", isOn: $realtimeSuggestionToggle)
                        .toggleStyle(.checkbox)
                }
                
                GridRow {
                    Divider().gridCellColumns(2)
                }
                
                GridRow(alignment: .center) {
                    Text("Accessibility Permission")
                    if axPermissionGranted {
                        Text("Granted")
                            .foregroundColor(.secondary)
                    } else {
                        Button("Grant Permission") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                    }
                }
                
                GridRow(alignment: .top) {
                    Text("Extension Permission")
                    VStack(alignment: .leading, spacing: 8) {
                        if extensionPermissionStatus == .granted {
                            Text("Granted")
                                .foregroundColor(.secondary)
                        } else {
                            Button("Grant Permission") {
                                NSWorkspace.openXcodeExtensionsPreferences()
                            }
                            Text(
                                "Extensions \(Image(systemName: "puzzlepiece.extension.fill")) → Xcode Source Editor \(Image(systemName: "info.circle")) → \(Constraint.AppName) for faster and full-featured code completion."
                            )
                            .foregroundColor(.secondary)
                        }
                    }
                }
                
                GridRow {
                    Divider().gridCellColumns(2)
                }
                
                GridRow(alignment: .center) {
                    Text("Accept suggestions with Tab")
                    Toggle("Enable", isOn: $acceptSuggestionWithTab)
                        .toggleStyle(.checkbox)
                }
                
                GridRow(alignment: .center) {
                    Text("Suggestion Debounce Time")
                    Stepper(value: $realtimeSuggestionDebounce, in: 0.1...5.0, step: 0.1) {
                        Text("\(realtimeSuggestionDebounce, specifier: "%.1f")")
                    }
                }
                
                GridRow(alignment: .center) {
                    Text("Disabled Language List")
                    Button("Open List") {
                        isSuggestionFeatureDisabledLanguageListViewOpen = true
                    }
                }
            }
            .gridColumnAlignment(.trailing)
            .padding(30)
            .sheet(isPresented: $isSuggestionFeatureDisabledLanguageListViewOpen) {
                CompletionDisabledLanguageList(isOpen: $isSuggestionFeatureDisabledLanguageListViewOpen)
            }
            
            Divider().padding(.leading)
            
            Form {
                CustomCompletionConfigInfoSection()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                
                Section {
                    ForEach(configManager.configs) { config in
                        CustomCompletionConfigRow(config: config) {
                            editConfig = config
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            
            HStack {
                Spacer()
                Button("Add config…") {
                    editConfig = nil
                    isShowingSheet = true
                }
                .controlSize(.large)
                .padding(.init(top: 0, leading: 0, bottom: 0, trailing: 16))
            }
            
            Spacer(minLength: 20)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle("Completions")
        .sheet(isPresented: $isShowingSheet) {
            CompletionEditView(config: nil) { config in
                configManager.addConfig(config)
            } removeConfig: { config in
                configManager.deleteConfig(config)
            }
        }
        .sheet(item: $editConfig) { config in
            CompletionEditView(config: config) { config in
                configManager.addOrUpdateConfig(config)
            } removeConfig: { config in
                configManager.deleteConfig(config)
            }
        }
    }
}

struct CustomCompletionConfigInfoSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: [.init(nsColor: .lightGray), .init(nsColor: .darkGray)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "keyboard.badge.ellipsis").font(.system(size: 24)).foregroundColor(.white)
                }
                .frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom Code Suggestion").font(.headline)
                    Text("Use custom model for code suggestion/completion, and effortlessly access them in the Xcode Editor window.").font(.subheadline).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct CustomCompletionConfigRow: View {
    @ObservedObject var config: LLMCompletionConfig
    var editConfigAction: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            CustomCompletionConfigIconView(size: 24)
            Text(config.name)
            Spacer()
            Button(action: {
                editConfigAction()
            }) {
                Image(systemName: "pencil")
                    .frame(width: 10, height: 10)
            }
            .buttonStyle(GetButtonStyle())
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }
}

struct CustomCompletionConfigIconView: View {
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
