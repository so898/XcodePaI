//
//  GeneralSettingSectionView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/11.
//

import SwiftUI

struct GeneralSettingSectionView: View {
    @State private var contentLayout = 0 // 0 for Vertical, 1 for Horizontal
    @State private var openConfigurationOnStartUp = Configer.openConfigurationWhenStartUp
    @State private var updateModelsWhenStartUp = Configer.updateModelsWhenStartUp
    @State private var forceLanguage: Configer.Language = Configer.forceLanguage
    @State private var showXcodeInspectorDebug = Configer.showXcodeInspectorDebug
    @State private var showLoadingWhenRequest = Configer.showLoadingWhenRequest
    
    @StateObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        ScrollView {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 18) {
                
                GridRow {
                    Text("Configuration Startup")
                    Toggle("Open Configuration", isOn: $openConfigurationOnStartUp)
                        .toggleStyle(.checkbox)
                        .onChange(of: openConfigurationOnStartUp) { _, newValue in
                            Configer.openConfigurationWhenStartUp = newValue
                        }
                }
                
                GridRow {
                    Text("")
                    Toggle("Update Models", isOn: $updateModelsWhenStartUp)
                        .toggleStyle(.checkbox)
                        .onChange(of: updateModelsWhenStartUp) { _, newValue in
                            Configer.updateModelsWhenStartUp = newValue
                        }
                }
                
                GridRow {
                    Divider().gridCellColumns(2)
                }
                
                GridRow(alignment: .top) {
                    Text("Display Language")
                    VStack(alignment: .leading) {
                        Picker("", selection: $languageManager.currentLanguage) {
                            ForEach(languageManager.supportedLanguages(), id: \.key) { (lang: (key: String?, name: String)) in
                                Text(lang.name).tag(lang.key as String?)
                            }
                        }
                        .frame(maxWidth: 150, alignment: .leading)
                        Text("Application restart required for language changed.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                GridRow {
                    Text("Response Language")
                    Picker("", selection: $forceLanguage) {
                        ForEach(Configer.Language.allCases, id: \.rawValue) { (language: Configer.Language) in
                            Text(language.rawValue.localizedString)
                                .tag(language)
                        }
                    }
                    .frame(maxWidth: 150, alignment: .leading)
                    .onChange(of: forceLanguage) { _, newValue in
                        Configer.forceLanguage = newValue
                    }
                }
                
                GridRow {
                    Divider().gridCellColumns(2)
                }
                
                GridRow {
                    Text("Xcode Inspector Debug")
                    Toggle("Show In Statusbar Menu", isOn: $showXcodeInspectorDebug)
                        .toggleStyle(.checkbox)
                        .onChange(of: showXcodeInspectorDebug) { _, newValue in
                            Configer.showXcodeInspectorDebug = newValue
                        }
                }
                
                GridRow {
                    Text("Show loading when requesting")
                    Toggle("Show In Statusbar Icon", isOn: $showLoadingWhenRequest)
                        .toggleStyle(.checkbox)
                        .onChange(of: showLoadingWhenRequest) { _, newValue in
                            Configer.showLoadingWhenRequest = newValue
                        }
                }
                
                GridRow {
                    Divider().gridCellColumns(2)
                }
                
                GridRow {
                    Text("Record List")
                    Button("Open List") {
                        openRecordListWindow()
                    }
                }
            }
            .gridColumnAlignment(.trailing)
            .padding(30)
        }
        .navigationTitle("General".localizedString)
    }
    
    func openRecordListWindow() {
        if let window = RecordListView.currentWindow, !window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        } else if let window = RecordListView.currentWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSMakeRect(0, 0, (NSScreen.main?.frame.width ?? 1200) / 2, (NSScreen.main?.frame.height ?? 1000) / 2),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Record List".localizedString
        window.isReleasedWhenClosed = false
        
        let hostingController = NSHostingController(rootView: RecordListView())
        window.contentView = hostingController.view
        window.makeKeyAndOrderFront(nil)
        
        RecordListView.currentWindow = window
    }
}
