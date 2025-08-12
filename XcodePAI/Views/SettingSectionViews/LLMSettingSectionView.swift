//
//  LLMSettingSectionView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/11.
//

import SwiftUI
import Combine

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

class LLMServerManager: ObservableObject {
    static let storageKey = "LLMServerStorage"
    
    @Published private(set) var servers: [LLMServer] = []
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadInitialValue()
        
        LocalStorage.shared.publisher(forKey: Self.storageKey)
            .replaceNil(with: [])
            .assign(to: \.servers, on: self)
            .store(in: &cancellables)
    }
    
    private func loadInitialValue() {
        LocalStorage.shared.getValue(forKey: Self.storageKey) { [weak self] (servers: [LLMServer]?) in
            self?.servers = servers ?? []
        }
    }
    
    func addServer(_ server: LLMServer) {
        var currentServers = servers
        currentServers.append(server)
        saveServers(currentServers)
    }
    
    func updateServer(_ server: LLMServer) {
        var currentServers = servers
        if let index = currentServers.firstIndex(where: { $0.name == server.name }) {
            currentServers[index] = server
            saveServers(currentServers)
        }
    }
    
    func deleteServer(at index: Int) {
        var currentServers = servers
        currentServers.remove(at: index)
        saveServers(currentServers)
    }
    
    private func saveServers(_ servers: [LLMServer]) {
        LocalStorage.shared.save(servers, forKey: Self.storageKey)
            .sink { _ in }
            .store(in: &cancellables)
    }
}

// MARK: - Main View
struct LLMSettingSectionView: View {
    
    // MARK: - State
    @StateObject private var serverManager = LLMServerManager()
    
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
                if serverManager.servers.count == 0 {
                    LLMServerEmptyRowView(showAddServerSheet: $isShowingSheet)
                } else {
                    ForEach(serverManager.servers) { server in
                        Section {
                            ForEach(platformSupportItems) { item in
                                PlatformRowView(item: item)
                            }
                        } header: {
                            LLMServiceSectionHeaderView(server: server)
                        }
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
            LLMServerCreateView(isPresented: $isShowingSheet) { server in
                serverManager.addServer(server)
            }
        }
    }
}

struct LLMServerCreateView: View {
    @Binding var isPresented: Bool
    
    var newLLMServerInfo: (LLMServer) -> Void
    
    @State private var name: String = ""
    @State private var iconName: String = "ollama"
    @State private var url: String = ""
    @State private var header: String = ""
    @State private var key: String = ""
    
    @State private var showIconList = false
        
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                VStack {
                    ZStack(alignment: .center){
                        Image(iconName)
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                        HStack{
                            Spacer()
                            VStack{
                                Spacer()
                                Button {
                                    // Change Icon Action
                                    showIconList = true
                                } label: {
                                    Image(systemName: "righttriangle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.init(top: 0, leading: 0, bottom: 8, trailing: 8))
                        }
                    }
                    .frame(width: 64, height: 64)
                    .popover(isPresented: $showIconList) {
                        LLMIconListView(isPresented: $showIconList, choosedIconName: $iconName)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("New LLM server")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 16) {
                        GridRow(alignment: .top) {
                            Text("Name")
                                .padding(.init(top: 7, leading: 0, bottom: 0, trailing: 0))
                            
                            VStack(spacing: 8) {
                                TextField("(*)", text: $name)
                                    .textFieldStyle(.roundedBorder)
                                    .controlSize(.large)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        
                        GridRow(alignment: .top) {
                            Text("URL")
                                .padding(.init(top: 7, leading: 0, bottom: 0, trailing: 0))
                            
                            VStack(spacing: 8) {
                                TextField("https://example.com", text: $url)
                                    .textFieldStyle(.roundedBorder)
                                    .controlSize(.large)
                                    .frame(maxWidth: .infinity)
                                if !url.isEmpty {
                                    Text(url + "/v1/completions")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        GridRow(alignment: .top) {
                            Text("Key")
                                .padding(.init(top: 7, leading: 0, bottom: 0, trailing: 0))
                            TextField("sk-xxxxxx (Optional)", text: $key)
                                .textFieldStyle(.roundedBorder)
                                .controlSize(.large)
                                .frame(maxWidth: .infinity)
                        }
                        
                        GridRow(alignment: .top) {
                            Text("Header")
                                .padding(.init(top: 7, leading: 0, bottom: 0, trailing: 0))
                            TextField("Authorization (Optional)", text: $header)
                                .textFieldStyle(.roundedBorder)
                                .controlSize(.large)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Add") {
                    newLLMServerInfo(LLMServer(name: name, iconName: iconName, url: url, authHeaderKey: header.isEmpty ? nil : header, privateKey: key.isEmpty ? nil : key))
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || url.isEmpty)
            }
        }
        .padding(16)
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
    let server: LLMServer
    
    var body: some View {
        HStack {
            Image(server.iconName)
                .resizable()
                .renderingMode(.template)
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                Text(server.url)
            }
            Spacer()
            HStack(spacing: 5){
                Button(action: {}) {
                    Image(systemName: "pencil")
                        .frame(width: 10, height: 10)
                }
                .buttonStyle(GetButtonStyle())
                
                Button(action: {}) {
                    Image(systemName: "arrow.trianglehead.clockwise")
                        .frame(width: 10, height: 10)
                }
                .buttonStyle(GetButtonStyle())
                
                Button(action: {}) {
                    Image(systemName: "plus")
                        .frame(width: 10, height: 10)
                }
                .buttonStyle(GetButtonStyle())
                
                Button(action: {}) {
                    Image(systemName: "minus")
                        .frame(width: 10, height: 10)
                }
                .buttonStyle(GetButtonStyle())
                
            }
            .frame(alignment: .trailing)
        }
        .padding(.init(top: 0, leading: 8, bottom: 0, trailing: 8))
        .frame(height: 40)
    }
}

struct LLMServerEmptyRowView: View {
    @Binding var showAddServerSheet: Bool
    
    var body: some View {
        VStack(alignment: .center) {
            HStack(alignment: .center) {
                Button(action: {
                    showAddServerSheet = true
                }) {
                    HStack {
                        Image(systemName: "plus")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 10, height: 10)
                        Text("Add LLM Server")
                    }
                }
                .buttonStyle(GetButtonStyle())
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 40)
    }
}

struct LLMServerModelRowView: View {
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
