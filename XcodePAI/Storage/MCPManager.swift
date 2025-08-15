//
//  MCPManager.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/16.
//

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
    
    func addMCP(_ mcp: LLMMCP) {
        var currentMCPs = mcps
        currentMCPs.append(mcp)
        saveMCPs(currentMCPs)
    }
    
    func updateMCP(_ mcp: LLMMCP) {
        var currentMCPs = mcps
        if let index = currentMCPs.firstIndex(where: { $0.id == mcp.id }) {
            currentMCPs[index] = mcp
            saveMCPs(currentMCPs)
        }
    }
    
    func deleteMCP(_ mcp: LLMMCP) {
        var currentMCPs = mcps
        if let index = currentMCPs.firstIndex(where: { $0.id == mcp.id }) {
            currentMCPs.remove(at: index)
            saveMCPs(currentMCPs)
        }
    }
    
    private func saveMCPs(_ mcps: [LLMMCP]) {
        self.mcps = mcps
        LocalStorage.shared.save(mcps, forKey: Self.storageKey)
            .sink { _ in }
            .store(in: &cancellables)
    }
}
