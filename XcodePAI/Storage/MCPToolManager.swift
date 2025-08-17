//
//  MCPToolManager.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/16.
//

import Combine

class MCPToolManager: ObservableObject {
    var storageKey: String
    
    @Published var tools: [LLMMCPTool] = []
    private var cancellables = Set<AnyCancellable>()
    
    init(_ mcp: String) {
        storageKey = Constraint.mcpToolStorageKeyPrefix + mcp
        loadInitialValue()
    }
    
    private func loadInitialValue() {
        LocalStorage.shared.fetch(forKey: storageKey)
            .replaceNil(with: [])
            .assign(to: \.tools, on: self)
            .store(in: &cancellables)
    }
    
    func changeName(_ mcp: String) {
        let newStorageKey = "LLMMCPToolStorage_" + mcp
        guard newStorageKey != storageKey else {
            return
        }
        LocalStorage.shared.renameStorage(oldKey: storageKey, newKey: newStorageKey)
        storageKey = newStorageKey
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
        LocalStorage.shared.save(tools, forKey: storageKey)
            .sink { _ in }
            .store(in: &cancellables)
    }
}
