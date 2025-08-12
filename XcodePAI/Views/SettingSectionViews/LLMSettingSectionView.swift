//
//  LLMSettingSectionView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/11.
//

import SwiftUI

// MARK: - Data Model
struct PlatformItem: Identifiable {
    let id = UUID()
    let name: String
    let iconName: String
    let lastUsed: String?
    let sizeOnDisk: String?
    
    enum Status {
        case builtIn
        case update
        case get
        case installed(lastUsed: String)
    }
    let status: Status
}

struct LLMService: Identifiable {
    let id = UUID()
    let name: String
    let iconName: String
}

// MARK: - Main View
struct LLMSettingSectionView: View {
    
    // MARK: - State
    @State private var selectedToolbarItem = "Components"
    @State private var isShowingSheet = false
    
    // MARK: - Data Source
    let platformSupportItems: [PlatformItem] = [
        .init(name: "macOS 15.5", iconName: "desktopcomputer", lastUsed: nil, sizeOnDisk: nil, status: .builtIn),
        .init(name: "iOS 18.5", iconName: "iphone", lastUsed: "8 days ago", sizeOnDisk: "8.84 GB on disk", status: .update),
        .init(name: "watchOS 11.5", iconName: "applewatch", lastUsed: nil, sizeOnDisk: "4.7 GB", status: .get),
        .init(name: "tvOS 18.5", iconName: "appletv", lastUsed: "--", sizeOnDisk: "4.43 GB on disk", status: .get),
        .init(name: "visionOS 2.5", iconName: "visionpro", lastUsed: nil, sizeOnDisk: "8.25 GB", status: .get)
    ]
    
    let otherInstalledItems: [PlatformItem] = [
        .init(name: "iOS 18.0 Simulator", iconName: "iphone", lastUsed: nil, sizeOnDisk: "8.36 GB on disk", status: .installed(lastUsed: "21 days ago")),
        .init(name: "iOS 17.5 Simulator", iconName: "iphone", lastUsed: nil, sizeOnDisk: "7.34 GB on disk", status: .installed(lastUsed: "Last year"))
    ]
    
    let serviceSections: [LLMService] = [
        .init(name: "OpenAI", iconName: "openai"),
        .init(name: "Ollama", iconName: "ollama"),
        .init(name: "Alibaba", iconName: "alibaba"),
        .init(name: "DeepSeek", iconName: "deepseek"),
    ]
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header for the List
            LLMSettingsListHeaderView()
            
            Divider()
            
            // Main List
            List {
                
                ForEach(serviceSections) { section in
                    Section {
                        ForEach(platformSupportItems) { item in
                            PlatformRowView(item: item)
                        }
                    } header: {
                        LLMServiceSectionHeaderView(service: section)
                    }
                }
            }
            .listStyle(.bordered) // Sidebar style gives us this type of section header.
            
            Divider()
            
            // Footer Buttons
            LLMSettingsFooterActionsView {
                isShowingSheet = true
            }
        }
        .padding(.init(top: 10, leading: 20, bottom: 10, trailing: 20))
        .navigationTitle("LLM")
        .sheet(isPresented: $isShowingSheet) {
            LLMServiceSectionHeaderView(service: .init(name: "OpenAI", iconName: "openai"))
        }
    }
}

// MARK: - Subviews
struct LLMSettingsListHeaderView: View {
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Text("Name")
            }
            Spacer()
            Text("Usage")
                .frame(width: 100)
            Text("Action")
                .frame(width: 200, alignment: .trailing)
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: LLM Service Section
struct LLMServiceSectionHeaderView: View {
    let service: LLMService
    
    var body: some View {
        HStack {
            Image(service.iconName)
                .resizable()
                .renderingMode(.template)
                .frame(width: 30, height: 30)
            Text(service.name)
            Spacer()
            HStack(spacing: 5){
                Button(action: {}) {
                    Image(systemName: "arrow.trianglehead.clockwise")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(GetButtonStyle())
                
                Button(action: {}) {
                    Image(systemName: "plus")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(GetButtonStyle())
                
                Button(action: {}) {
                    Image(systemName: "minus")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(GetButtonStyle())
                
            }
            .frame(alignment: .trailing)
        }
        .frame(height: 40)
    }
}

struct ProviderRowView: View {
    var body: some View {
        
    }
}

struct PlatformRowView: View {
    let item: PlatformItem
    
    var body: some View {
        HStack {
            Image(systemName: item.iconName)
                .font(.title2)
                .frame(width: 30)
            Text(item.name)
                .font(.headline)
            
            Spacer()
            
            // Last Used Column
            if case .installed(let lastUsed) = item.status {
                Text(lastUsed)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 150)
            } else if let lastUsed = item.lastUsed {
                Text(lastUsed)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 150)
            } else {
                Text("")
                    .frame(width: 150)
            }
            
            // Info / Action Column
            HStack {
                Spacer()
                if let size = item.sizeOnDisk {
                    Text(size)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                switch item.status {
                case .builtIn:
                    Text("Built-in")
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                case .update:
                    Button("Update") {}
                        .buttonStyle(GetButtonStyle())
                case .get:
                    Button("Get") {}
                        .buttonStyle(GetButtonStyle())
                case .installed:
                    // No button for already installed items in this column
                    EmptyView()
                }
            }
            .frame(width: 200, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }
}


struct LLMSettingsFooterActionsView: View {
    var addButtonAction: (() -> Void)
    
    var body: some View {
        HStack {
            Button(action: {
                addButtonAction()
            }) {
                Image(systemName: "plus")
                    .frame(width: 20, height: 20)
            }
            Spacer()
        }
        .padding(12)
        .buttonStyle(.borderless) // Use borderless for icon-only buttons
        .background(Color(nsColor: .controlBackgroundColor))
    }
}


// MARK: - Custom Button Style
struct GetButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .padding(.vertical, 6)
            .padding(.horizontal, 16)
            .background(Color.gray.opacity(0.4))
            .foregroundColor(.white)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}