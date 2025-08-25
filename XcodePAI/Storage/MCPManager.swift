//
//  MCPManager.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/16.
//

import Foundation

class MCPManager: ObservableObject {
    static let storageKey = Constraint.mcpStorageKey
    
    @Published private(set) var mcps: [LLMMCP] = []
    
    init() {
        loadInitialValue()
    }
    
    private func loadInitialValue() {
        mcps = StorageManager.shared.mcps
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
        StorageManager.shared.updateMCPs(mcps)
    }
}
