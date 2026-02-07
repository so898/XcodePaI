//
//  GitIntegrationSettingSectionView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/12/24.
//

import SwiftUI

struct GitIntegrationSettingSectionView: View {
    @State private var showGitCommitInStatusMenu = Configer.showGitCommitInStatusMenu
    @State private var gitCommitGenerateUseThink = Configer.gitCommitGenerateUseThink
    @State private var gitCommitGenerateTimeout = Configer.gitCommitGenerateTimeout
    
    var body: some View {
        ScrollView {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 18) {
                
                GridRow {
                    Text("Open Git commit window within status bar menu")
                    Toggle("Enabled", isOn: $showGitCommitInStatusMenu)
                        .toggleStyle(.checkbox)
                        .onChange(of: showGitCommitInStatusMenu) { _, newValue in
                            Configer.showGitCommitInStatusMenu = newValue
                        }
                }
                
                GridRow {
                    Divider().gridCellColumns(2)
                }
                
                GridRow {
                    Text("Generate commit message with think")
                    Toggle("Enabled", isOn: $gitCommitGenerateUseThink)
                        .toggleStyle(.checkbox)
                        .onChange(of: gitCommitGenerateUseThink) { _, newValue in
                            Configer.gitCommitGenerateUseThink = newValue
                        }
                }
                
                GridRow(alignment: .center) {
                    Text("Generate timeout")
                    Stepper(value: $gitCommitGenerateTimeout, in: 60...600, step: 30) {
                        Text("\(gitCommitGenerateTimeout, specifier: "%.0f")")
                    }.onChange(of: gitCommitGenerateTimeout) { _, newValue in
                        Configer.gitCommitGenerateTimeout = newValue
                    }
                }
                
            }
            .gridColumnAlignment(.trailing)
            .padding(30)
        }
        .navigationTitle("Integration".localizedString)
    }
}
