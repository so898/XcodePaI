//
//  MCPSetting.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/16.
//

import SwiftUI
import Combine

class MCPManager: ObservableObject {
    static let storageKey = "LLMMCPStorage"
    
    @Published private(set) var mcps: [LLMMCP] = []
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadInitialValue()
    }
    
    private func loadInitialValue() {
        LocalStorage.shared.fetch(forKey: Self.storageKey)
            .replaceNil(with: [])
            .assign(to: \.mcps, on: self)
            .store(in: &cancellables)
    }
    
    func addModelProvider(_ mcp: LLMMCP) {
        var currentMCPs = mcps
        currentMCPs.append(mcp)
        saveModelProviders(currentMCPs)
    }
    
    func updateModelProvider(_ mcp: LLMMCP) {
        var currentMCPs = mcps
        if let index = currentMCPs.firstIndex(where: { $0.id == mcp.id }) {
            currentMCPs[index] = mcp
            saveModelProviders(currentMCPs)
        }
    }
    
    func deleteModelProvider(_ mcp: LLMMCP) {
        var currentMCPs = mcps
        if let index = currentMCPs.firstIndex(where: { $0.id == mcp.id }) {
            currentMCPs.remove(at: index)
            saveModelProviders(currentMCPs)
        }
    }
    
    private func saveModelProviders(_ mcps: [LLMMCP]) {
        self.mcps = mcps
        LocalStorage.shared.save(mcps, forKey: Self.storageKey)
            .sink { _ in }
            .store(in: &cancellables)
    }
}

struct MCPSettingSectionView: View {
    @StateObject private var mcpManager = MCPManager()
    
    var body: some View {
        NavigationStack {
            // Group View for navigaion change
            Group {
                MCPListView(mcpManager: mcpManager)
            }
            .navigationDestination(for: LLMMCP.self) { mcp in
//                ModelProviderDetailView(providerManager: providerManager, provider: provider)
            }
        }
    }
}

// MARK: - Model List View
struct MCPListView: View {
    @ObservedObject var mcpManager: MCPManager
    @State private var isShowingSheet = false
    
    var body: some View {
        ScrollView {
            VStack {
                Form {
                    MCPInfoSection()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    
                    Section {
                        ForEach(mcpManager.mcps) { mcp in
                            NavigationLink(value: mcp) {
                                MCPRow(mcp: mcp)
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                
                HStack {
                    Spacer()
                    Button("Add a MCP...") {
                        isShowingSheet = true
                    }
                    .padding(.init(top: 0, leading: 0, bottom: 0, trailing: 16))
                }
            }
            .padding(.init(top: 0, leading: 16, bottom: 24, trailing: 16))
        }
        .navigationTitle("MCP")
        .sheet(isPresented: $isShowingSheet) {
//            ModelProviderEditView(currentProvider: nil){ provider in
//                providerManager.addModelProvider(provider)
//            }
        }
    }
}

struct MCPIconView: View {
    @ObservedObject var mcp: LLMMCP
    let size: CGFloat
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                .fill(Color.blue.opacity(0.7))
            Image(systemName: "server.rack")
                .resizable()
                .renderingMode(.template)
                .padding(4)
        }
        .frame(width: size, height: size)
    }
}

struct MCPInfoSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: "333333"), .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "square.stack.3d.forward.dottedline").font(.system(size: 32)).foregroundColor(.white)
                }
                .frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 4) {
                    Text("MCP").font(.headline)
                    Text("Supercharge your Xcode experience with your choice of MCP services. Third-party MCPs will have access to your project files and code.").font(.subheadline).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    Link("About MCP...", destination: URL(string: "https://modelcontextprotocol.io/")!).font(.subheadline).padding(.top, 4)
                }
            }
        }
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct MCPRow: View {
    @ObservedObject var mcp: LLMMCP
    
    var body: some View {
        HStack(spacing: 12) {
            MCPIconView(mcp: mcp, size: 24)
            Text(mcp.name)
            Spacer()
            Text(mcp.enabled ? "Enabled" : "Disabled")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }
}
