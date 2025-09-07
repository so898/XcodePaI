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
                
                GridRow {
                    Text("Response Language")
                    Picker("", selection: $forceLanguage) {
                        ForEach(Configer.Language.allCases, id: \.rawValue) { (language: Configer.Language) in
                            Text(language.rawValue)
                                .tag(language)
                        }
                    }
                    .frame(maxWidth: 150, alignment: .leading)
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
