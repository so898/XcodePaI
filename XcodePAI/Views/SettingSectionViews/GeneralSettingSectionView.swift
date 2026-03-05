//
//  GeneralSettingSectionView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/11.
//

import SwiftUI

struct GeneralSettingSectionView: View {
    @State private var openConfigurationOnStartUp = Configer.openConfigurationWhenStartUp
    @State private var updateModelsWhenStartUp = Configer.updateModelsWhenStartUp
    @State private var forceLanguage: Configer.Language = Configer.forceLanguage
    @State private var forceLanguageIn: Configer.ForceLanguageIn = Configer.forceLanguageIn
    @State private var showXcodeInspectorDebug = Configer.showXcodeInspectorDebug
    @State private var showLoadingWhenRequest = Configer.showLoadingWhenRequest
    @State private var proxyString = Configer.debugNetworkProxy
    
    @StateObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        ScrollView {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 18) {
                
                GridRow {
                    Text("Startup Actions")
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
                        Text("Application restart required for language change.")
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
                
                if forceLanguage != .default {
                    GridRow {
                        Text("Language Directive In")
                        Picker("", selection: $forceLanguageIn) {
                            ForEach(Configer.ForceLanguageIn.allCases, id: \.rawValue) { (language: Configer.ForceLanguageIn) in
                                Text(language.rawValue.localizedString)
                                    .tag(language)
                            }
                        }
                        .frame(maxWidth: 150, alignment: .leading)
                        .onChange(of: forceLanguageIn) { _, newValue in
                            Configer.forceLanguageIn = newValue
                        }
                    }
                }
                
                GridRow {
                    Divider().gridCellColumns(2)
                }
                
                GridRow {
                    Text("Show loading when requesting")
                    Toggle("Show in status bar icon", isOn: $showLoadingWhenRequest)
                        .toggleStyle(.checkbox)
                        .onChange(of: showLoadingWhenRequest) { _, newValue in
                            Configer.showLoadingWhenRequest = newValue
                        }
                }
                
                GridRow {
                    Text("Xcode Inspector Debug")
                    Toggle("Show in status bar menu", isOn: $showXcodeInspectorDebug)
                        .toggleStyle(.checkbox)
                        .onChange(of: showXcodeInspectorDebug) { _, newValue in
                            Configer.showXcodeInspectorDebug = newValue
                        }
                }
                
                GridRow {
                    Divider().gridCellColumns(2)
                }
                
                GridRow {
                    Text("Record List")
                    Button("Open List") {
                        WindowManager.shared.openRecordListWindow()
                    }
                }
                
                GridRow {
                    Divider().gridCellColumns(2)
                }
                
                GridRow(alignment: .center) {
                    Text("Request Proxy")
                    TextField("http://127.0.0.1:8080", text: $proxyString)
                        .textFieldStyle(.plain)
                        .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                        .background(Color.black.opacity(0.3))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray))
                        .cornerRadius(5)
                        .onChange(of: proxyString) { _, newValue in
                            Configer.debugNetworkProxy = newValue
                        }
                }
            }
            .gridColumnAlignment(.trailing)
            .padding(30)
        }
        .navigationTitle("General".localizedString)
    }
}
