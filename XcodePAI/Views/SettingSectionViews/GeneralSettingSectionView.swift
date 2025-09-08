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
    @State private var forceLanguage: Configer.Language = Configer.forceLanguage
    @State private var showXcodeInstpectorDebug = Configer.showXcodeInstpectorDebug
    
    @StateObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        ScrollView {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 18) {
                
                GridRow {
                    Text("Configuration window")
                    Toggle("Open Configuration when StartUp", isOn: $openConfigurationOnStartUp)
                        .toggleStyle(.checkbox)
                        .onChange(of: openConfigurationOnStartUp) { _, newValue in
                            Configer.openConfigurationWhenStartUp = newValue
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
                    Toggle("Show In Statusbar Menu", isOn: $showXcodeInstpectorDebug)
                        .toggleStyle(.checkbox)
                        .onChange(of: showXcodeInstpectorDebug) { _, newValue in
                            Configer.showXcodeInstpectorDebug = newValue
                        }
                }
            }
            .gridColumnAlignment(.trailing)
            .padding(30)
        }
        .navigationTitle("General")
    }
}
