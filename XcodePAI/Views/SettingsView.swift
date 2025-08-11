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
        TabItem(id: 1, title: "LLM", imageName: "wand.and.stars"),
        TabItem(id: 2, title: "Chat Proxy", imageName: "chart.bar.horizontal.page"),
        TabItem(id: 3, title: "Completion", imageName: "pencil.and.list.clipboard"),
        TabItem(id: 4, title: "About", imageName: "info.circle.fill"),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            
            switch selectedTabId {
            case 0: GeneralSettingSectionView()
            case 1: LLMSettingSectionView()
            case 2: ChatProxySettingSectionView()
            default: GeneralSettingSectionView()
            }
            
        }
        .toolbar {
            ToolbarItemGroup(placement: .principal) {
                HStack(spacing: 4) {
                    ForEach(tabs) { tab in
                        Button(action: { selectedTabId = tab.id }) {
                            VStack(spacing: 4) {
                                Image(systemName: tab.imageName)
                                    .font(.system(size: 20))
                                    .foregroundStyle(selectedTabId == tab.id ? Color(nsColor: .systemBlue) : Color.primary)
                                Text(tab.title)
                                    .font(.caption)
                                    .foregroundStyle( (selectedTabId == tab.id ? Color(nsColor: .systemBlue) : Color.primary))
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .frame(width: 90)
                        }
                        .background(selectedTabId == tab.id ? Color(nsColor: .darkGray).opacity(0.5) : Color.clear)
                        .cornerRadius(6)
                        .buttonStyle(.plain)
                        
                    }
                }
                .padding(.horizontal)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
