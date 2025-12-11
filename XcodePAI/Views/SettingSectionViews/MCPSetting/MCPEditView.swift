//
//  MCPEditView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/16.
//

import SwiftUI

class KVObject: Identifiable {
    let id = UUID()
    @Published var key: String
    @Published var value: String
    
    init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

class ArgObject: Identifiable {
    let id = UUID()
    @Published var value: String
    
    init(value: String) {
        self.value = value
    }
}

struct MCPEditView: View {
    let currentMCP: LLMMCP?
    
    var createOrUpdateMCP: (LLMMCP, [LLMMCPTool]?) -> Void
    
    var removeMCP: ((LLMMCP) -> Void)?
    
    @State private var name: String = ""
    @State private var description: String = ""
    
    @State private var url: String = ""
    @State private var headers = [KVObject]()
    
    @State private var command: String = ""
    @State private var args = [ArgObject]()
    
    @State private var isLocal: Bool = false
    
    @State var showCreateMCPAlert = false
    @State var showCreateMCPLoading = false
    
    // Close Sheet
    @Environment(\.dismiss) var dismiss
    
    init(mcp: LLMMCP?, createOrUpdateMCP: @escaping (LLMMCP, [LLMMCPTool]?) -> Void, removeMCP: ((LLMMCP) -> Void)? = nil) {
        self.currentMCP = mcp
        self.createOrUpdateMCP = createOrUpdateMCP
        if let mcp = mcp {
            _name = State(initialValue: mcp.name)
            _url = State(initialValue: mcp.isLocal() ? "" : mcp.url)
            if let description = mcp.description {
                _description = State(initialValue: description)
            }
            if let headers = mcp.headers {
                var objects = [KVObject]()
                for key in headers.keys {
                    if let value = headers[key] {
                        objects.append(KVObject(key: key, value: value))
                    }
                }
                _headers = State(initialValue: objects)
            }
            
            _command = State(initialValue: mcp.command ?? "")
            if let args = mcp.args {
                var objects = [ArgObject]()
                for value in args {
                    objects.append(ArgObject(value: value))
                }
                _args = State(initialValue: objects)
            }
            
            _isLocal = State(initialValue: mcp.isLocal())
        }
        self.removeMCP = removeMCP
    }
    
    var body: some View {
        ZStack {            
            VStack(alignment: .leading, spacing: 20) {
                headerView
                
                formSection
                
                Spacer()
                
                buttonsSection
            }
            .padding()
        }
        .alert("MCP Service Check Fail.", isPresented: $showCreateMCPAlert) {
        }
        .overlay {
            Group {
                if showCreateMCPLoading {
                    ZStack {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                        
                        // Loading
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                                .scaleEffect(1.5)
                            
                            Text("Checking MCP…")
                                .foregroundColor(.primary)
                                .font(.headline)
                        }
                        .padding(30)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 5)
                        )
                    }
                    .zIndex(999) // On the top
                    .transition(.opacity)
                }
            }
        }
    }
    
    // MARK: - subviews
    
    private var headerView: some View {
        HStack(spacing: 15) {
            ZStack {
                Color.black
                Image(systemName: "square.stack.3d.forward.dottedline").font(.system(size: 24)).foregroundColor(.white)
            }
            .cornerRadius(10)
            .frame(width: 64, height: 64)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(currentMCP?.name ?? "Add a MCP service".localizedString)
                    .font(.headline)
                    .fontWeight(.bold)
                Text(currentMCP != nil ? (isLocal ? "Local MCP".localizedString : "Remote MCP".localizedString) : "Enter the information for the MCP.".localizedString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(8)
        .background(Color.black.opacity(0.25))
        .cornerRadius(12)
    }
    
    private var formSection: some View {
        VStack(spacing: 8) {
            VStack(spacing: 0) {
                FormFieldRow(label: "Name".localizedString, content: {
                    TextField("Name".localizedString, text: $name)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                })
            }
            .background(Color.black.opacity(0.25))
            .cornerRadius(12)
            
            Picker("", selection: $isLocal) {
                Text("Local".localizedString).tag(true)
                Text("Remote".localizedString).tag(false)
            }.pickerStyle(SegmentedPickerStyle())
                .padding()
            
            if (isLocal) {
                VStack(spacing: 0) {
                    FormFieldRow(label: "Command".localizedString, content: {
                        TextField("npx".localizedString, text: $command)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    })
                }
                .background(Color.black.opacity(0.25))
                .cornerRadius(12)
                
                VStack(spacing: 0) {
                    
                    ForEach ($args) { arg in
                        FormDeletableFieldRow(label: "") {
                            TextField("Argument".localizedString, text: arg.value)
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.leading)
                        } deleteAction: {
                            if let index = args.firstIndex(where: { $0.id == arg.id }) {
                                args.remove(at: index)
                            }
                        }
                        
                        Divider().padding(.leading)
                    }
                    
                    HStack {
                        Spacer()
                        Button {
                            args.append(ArgObject(value: ""))
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 20, height: 20)
                            Text("Add Argument".localizedString)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    
                }
                .background(Color.black.opacity(0.25))
                .cornerRadius(12)
            } else {
                VStack(spacing: 0) {
                    FormFieldRow(label: "URL".localizedString, content: {
                        TextField("https://mcp.example.com".localizedString, text: $url)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    })
                }
                .background(Color.black.opacity(0.25))
                .cornerRadius(12)
                
                VStack(spacing: 0) {
                    
                    ForEach ($headers) { header in
                        FormKVFieldRow {
                            TextField("Header Key".localizedString, text: header.key)
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.leading)
                        } value: {
                            TextField("Header Value".localizedString, text: header.value)
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                        } deleteAction: {
                            if let index = headers.firstIndex(where: { $0.id == header.id }) {
                                headers.remove(at: index)
                            }
                        }
                        
                        Divider().padding(.leading)
                    }
                    
                    HStack {
                        Spacer()
                        Button {
                            headers.append(KVObject(key: "", value: ""))
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 20, height: 20)
                            Text("Add Header".localizedString)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    
                }
                .background(Color.black.opacity(0.25))
                .cornerRadius(12)
            }
        }
    }
        
    private var buttonsSection: some View {
        HStack {
            if currentMCP != nil {
                Button(role: .destructive) {
                    if let currentMCP = currentMCP, let removeMCP = removeMCP {
                        removeMCP(currentMCP)
                    }
                    dismiss()
                } label: {
                    Text("Delete MCP".localizedString)
                        .frame(maxWidth: .infinity)
                }
                .tint(Color.red.opacity(0.7))
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: 200)
            }
            
            Spacer()
            
            Button("Cancel".localizedString) {
                dismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            
            
            Button("Save".localizedString) {
                showCreateMCPLoading = true
                
                let newMCP = {
                    if isLocal {
                        var args = [String]()
                        for arg in self.args {
                            args.append(arg.value)
                        }
                        return LLMMCP(id: UUID(), name: name, command: command, args: args)
                    }
                    var headers = [String: String]()
                    for header in self.headers {
                        headers[header.key] = header.value
                    }
                    return LLMMCP(id: currentMCP?.id ?? UUID(), name: name, description: description.isEmpty ? nil : description, url: url, headers: headers.count > 0 ? headers : nil)
                }()
                
                MCPRunner.shared.check(mcp: newMCP) { success, tools in
                    showCreateMCPLoading = false
                    
                    guard success else {
                        showCreateMCPAlert = true
                        return
                    }
                    
                    createOrUpdateMCP(newMCP, tools)
                    
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled((url.isEmpty && command.isEmpty) || name.isEmpty)
        }
    }
}
