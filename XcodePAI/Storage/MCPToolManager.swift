//
//  MCPToolManager.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/16.
//

import Foundation

class MCPToolManager: ObservableObject {
    var storageKey: String
    
    @Published var tools: [LLMMCPTool] = []
    
    init(_ mcp: String) {
        storageKey = mcp
        loadInitialValue()
    }
    
    private func loadInitialValue() {
        tools = StorageManager.shared.toolsWithMCP(name: storageKey)
    }
    
    func changeName(_ mcp: String) {
        guard mcp != storageKey else {
            return
        }
        StorageManager.shared.renameTools(from: storageKey, to: mcp)
        storageKey = mcp
    }
    
    func addTool(_ tool: LLMMCPTool) {
        var currentTools = tools
        currentTools.append(tool)
        saveTools(currentTools)
    }
    
    func replaceTools(_ tools: [LLMMCPTool]) {
        self.tools = tools
        saveTools(tools)
    }
    
    func updateTool(_ tool: LLMMCPTool) {
        var currentTools = tools
        if let index = currentTools.firstIndex(where: { $0.id == tool.id }) {
            currentTools[index] = tool
            saveTools(currentTools)
        }
    }
    
    func deleteTool(_ tool: LLMMCPTool) {
        var currentTools = tools
        if let index = currentTools.firstIndex(where: { $0.id == tool.id }) {
            currentTools.remove(at: index)
            saveTools(currentTools)
        }
    }
    
    private func saveTools(_ tools: [LLMMCPTool]) {
        self.tools = tools
        StorageManager.shared.updateMCPTools(tools, mcpName: storageKey)
    }
}
