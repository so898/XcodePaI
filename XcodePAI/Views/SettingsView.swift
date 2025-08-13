//
//  SettingsView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/11.
//

import SwiftUI

struct SettingsView: View {
    
    @State private var selectedTabId = 0
    
    // Tab model
    struct TabItem: Identifiable {
        let id: Int
        let title: String
        let imageName: String
    }
    
    // Tab Infos
    let tabs = [
        TabItem(id: 0, title: "General", imageName: "gearshape"),
        TabItem(id: 1, title: "Provider", imageName: "sparkles.square.filled.on.square"),
        TabItem(id: 2, title: "Chat Proxy", imageName: "chart.bar.horizontal.page"),
        TabItem(id: 3, title: "Completion", imageName: "pencil.and.list.clipboard"),
        TabItem(id: 4, title: "About", imageName: "info.circle.fill"),
    ]
    
    var body: some View {
        TabView {
            ForEach(tabs) { tab in
                Tab(tab.title, systemImage: tab.imageName) {
                    switch tab.id {
                    case 0: GeneralSettingSectionView()
                    case 1: ModelProviderSettingSectionView()
                    case 2: ChatProxySettingSectionView()
                    default: GeneralSettingSectionView()
                    }
                }
            }
        }
        .tabViewStyle(SidebarAdaptableTabViewStyle())
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
