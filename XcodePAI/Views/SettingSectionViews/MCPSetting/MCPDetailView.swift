//
//  MCPDetailView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/16.
//

import SwiftUI

// MARK: - Provider Detail View
struct MCPDetailView: View {
    @EnvironmentObject private var loadingState: LoadingState
    
    @ObservedObject var mcpManager: MCPManager
    @ObservedObject var toolManager: MCPToolManager
    
    @State private var mcp: LLMMCP
    
    @State private var sortOrder = [KeyPathComparator(\LLMMCPTool.name)]
    
    @State private var isShowingSheet = false
    @State private var isShowingSuccessAlert = false
    @State private var isReloadSuccess = false
    
    @Environment(\.dismiss) private var dismiss
    
    init(mcpManager: MCPManager, mcp: LLMMCP) {
        self.mcpManager = mcpManager
        toolManager = MCPToolManager(mcp.name)
        _mcp = State(initialValue: mcp)
    }
    
    var body: some View {
        VStack(spacing: 0) {
           MCPDetailHeader(mcp: mcp, isEnabled: mcpEnableToggleBinding(for: mcp)) {
                isShowingSheet = true
            } refreshToolAction: {
                fetchTools()
            }
            
            Divider()
            
            toolsTable
        }
        .navigationTitle(mcp.name)
        .sheet(isPresented: $isShowingSheet) {
            MCPEditView(mcp: mcp){ mcp, tools in
                self.mcp = mcp
                toolManager.changeName(mcp.name)
                toolManager.replaceTools(tools ?? [])
                mcpManager.updateMCP(mcp)
            } removeMCP: { removeMCP in
                mcpManager.deleteMCP(removeMCP)
                dismiss()
            }
        }
        .alert(isReloadSuccess ? "Reload tools success." : "Reload tools fail.", isPresented: $isShowingSuccessAlert) {
        }
    }
    
    private func mcpEnableToggleBinding(for mcp: LLMMCP) -> Binding<Bool> {
        Binding<Bool>(
            get: { mcp.enabled },
            set: { newValue in
                let newMCP = mcp
                newMCP.enabled = newValue
                self.mcp = newMCP
                mcpManager.updateMCP(newMCP)
            }
        )
    }
    
    private func fetchTools() {
        LoadingState.shared.show(text: "Checking MCP…".localizedString)
        mcp.checkService { success, tools in
            isReloadSuccess = success
            
            guard success else {
                isShowingSuccessAlert = true
                return
            }
            
            toolManager.replaceTools(tools ?? [])
            LoadingState.shared.hide()
            isShowingSuccessAlert = true
        }
    }
    
    @State var showTestAlert = false
    @State var testResult = false
    private var toolsTable: some View {
        Table(toolManager.tools, sortOrder: $sortOrder) {
            TableColumn("Name", value: \LLMMCPTool.name) { tool in
                HStack{
                    Text(tool.name)
                    Spacer()
                }
            }
            
            TableColumn("Description", value: \LLMMCPTool.description) { tool in
                HStack{
                    Text(tool.description)
                    Spacer()
                }
            }
        }
        .tableStyle(.inset)
        .onChange(of: sortOrder) {
            toolManager.tools.sort(using: sortOrder)
        }
    }
}

// Helper View to break down complex expression
private struct ToggleView: View {
    let model: LLMModel
    @ObservedObject var modelManager: ModelManager // Replace with your manager's type
    
    var body: some View {
        HStack {
            Spacer()
            Toggle("", isOn: toggleBinding(for: model))
                .labelsHidden()
                .toggleStyle(.checkbox)
            Spacer()
        }
    }
    
    // Dedicated function for Binding creation
    private func toggleBinding(for model: LLMModel) -> Binding<Bool> {
        Binding<Bool>(
            get: { model.enabled },
            set: { newValue in
                let newModel = model
                newModel.enabled = newValue
                modelManager.updateModel(newModel)
            }
        )
    }
}

// MARK: - Reusable Subviews

struct MCPDetailHeader: View {
    @ObservedObject var mcp: LLMMCP
    @Binding var isEnabled: Bool
    var editMCPAction: () -> Void
    var refreshToolAction: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "333333"), .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "square.stack.3d.forward.dottedline").font(.system(size: 24)).foregroundColor(.white)
            }
            .frame(width: 40, height: 40)
            
            Text(mcp.name).font(.title2).fontWeight(.medium)
            
            Spacer()
            
            Button(action: {
                refreshToolAction()
            }) {
                Image(systemName: "arrow.trianglehead.clockwise")
                    .frame(width: 10, height: 10)
            }
            .buttonStyle(GetButtonStyle())
            
            Button(action: {
                editMCPAction()
            }) {
                Image(systemName: "pencil")
                    .frame(width: 10, height: 10)
            }
            .buttonStyle(GetButtonStyle())
            
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding()
    }
}
