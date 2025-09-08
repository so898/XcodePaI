//
//  SettingsView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/11.
//

import SwiftUI

struct SettingsView: View {
    
    // Tab model
    struct TabItem: Identifiable {
        let id: Int
        let title: String
        let imageName: String
        let view: AnyView
    }
    
    @State private var selection: Int = 0
    
    @StateObject private var languageManager = LanguageManager.shared
    
    // Tab Infos
    var tabs: [TabItem] {
        [
            TabItem(id: 0, title: "General".localizedString, imageName: "gearshape", view: AnyView(GeneralSettingSectionView())),
            TabItem(id: 1, title: "Provider".localizedString, imageName: "sparkles.square.filled.on.square", view: AnyView(ModelProviderSettingSectionView())),
            TabItem(id: 2, title: "MCP".localizedString, imageName: "square.stack.3d.forward.dottedline", view: AnyView(MCPSettingSectionView())),
            TabItem(id: 3, title: "Chat Proxy".localizedString, imageName: "chart.bar.horizontal.page", view: AnyView(ChatProxySettingSectionView())),
            TabItem(id: 4, title: "Completions".localizedString, imageName: "pencil.and.list.clipboard", view: AnyView(CompletionSettingSectionView())),
            TabItem(id: 5, title: "Plugin".localizedString, imageName: "batteryblock.stack", view: AnyView(PluginSettingSectionView())),
            TabItem(id: 6, title: "About".localizedString, imageName: "info.circle.fill", view: AnyView(AboutSettingSectionView()))
        ]
    }
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(tabs) { tab in
                    HStack {
                        Image(systemName: tab.imageName)
                        Text(tab.title)
                    }
                    .tag(tab.id)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Settings")
            .frame(minWidth: 180, idealWidth: 200, maxWidth: 250)
        } detail: {
            Group {
                if let selectedTab = tabs.first(where: { $0.id == selection }) {
                    selectedTab.view
                } else {
                    GeneralSettingSectionView()
                }
            }
            .navigationTitle(tabs.first { $0.id == selection }?.title ?? "General")
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.locale, languageManager.currentLanguage == nil ? .current : .init(identifier: languageManager.currentLanguage!))
    }
}
