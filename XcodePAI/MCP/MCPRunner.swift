//
//  MCPRunner.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/17.
//

import Foundation
import MCP

class MCPRunner {
    static let shared = MCPRunner()
    
    private let queue = DispatchQueue(label: "xcodepai.mcp.runner.queue")
    
    private var mcps = [LLMMCP]()
    private var tools = [LLMMCPTool]()
    
    init() {
        reload()
    }
    
    func reload() {
        queue.async {[weak self] in
            guard let `self` = self else {
                return
            }
            
            mcps.removeAll()
            tools.removeAll()
            
            LocalStorage.shared.getValue(forKey: Constraint.mcpStorageKey) { [weak self] (mcps: [LLMMCP]?) in
                guard let `self` = self else {
                    return
                }
                queue.async {[weak self] in
                    guard let `self` = self, let mcps else {
                        return
                    }
                    for mcp in mcps {
                        self.mcps.append(mcp)
                        
                        LocalStorage.shared.getValue(forKey: Constraint.mcpToolStorageKeyPrefix + mcp.name) { [weak self] (tools: [LLMMCPTool]?) in
                            guard let `self` = self, let tools else {
                                return
                            }
                            queue.async {[weak self] in
                                guard let `self` = self else {
                                    return
                                }
                                
                                for tool in tools {
                                    self.tools.append(tool)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func tools(_ mcp: String) -> [LLMMCPTool] {
        var ret = [LLMMCPTool]()
        queue.sync {[weak self] in
            guard let `self` = self else {
                return
            }
            
            for tool in tools {
                if tool.mcp == mcp {
                    ret.append(tool)
                }
            }
        }
        
        return ret
    }
    
    func run(mcpName: String, toolName: String, arguments: String?, complete: @escaping (String?, Error?) -> Void) {
        
        var useMCP: LLMMCP?
        var useTool: LLMMCPTool?
        queue.sync {[weak self] in
            guard let `self` = self else {
                return
            }
            
            for mcp in mcps {
                if mcp.name == mcpName {
                    useMCP = mcp
                    break
                }
            }
            
            if let useMCP = useMCP {
                for tool in tools {
                    if tool.mcp == useMCP.name, tool.name == toolName {
                        useTool = tool
                    }
                }
            }
        }
        
        guard let mcp = useMCP else {
            complete(nil, NSError(domain: "MCPError", code: 0, userInfo: [NSLocalizedDescriptionKey: "MCP not found"]))
            return
        }
        
        guard let tool = useTool else {
            complete(nil, NSError(domain: "MCPError", code: 0, userInfo: [NSLocalizedDescriptionKey: "MCP tool not found"]))
            return
        }
        
        
        Task {
            let client = Client(name: Constraint.AppName, version: Constraint.AppVersion)
            
            let transport = HTTPClientTransport(
                endpoint: URL(string: mcp.url)!,
                streaming: true) { request in
                    guard let headers = mcp.headers else {
                        return request
                    }
                    var newRequest = request
                    for key in headers.keys {
                        if let value = headers[key] {
                            newRequest.setValue(value, forHTTPHeaderField: key)
                        }
                    }
                    return newRequest
                }
            let result = try await client.connect(transport: transport)
            
            let arguments: [String: Value]? = {
                guard let arguments = arguments, let data = arguments.data(using: .utf8) else {
                    return nil
                }
                
                if let value = try? JSONDecoder().decode([String: Value].self, from: data) {
                    return value
                }
                
                return nil
            }()
            
            // Call a tool with arguments
            let (content, isError) = try await client.callTool(
                name: tool.name,
                arguments: arguments
            )
            
            if let isError, isError {
                DispatchQueue.main.async {
                    complete(nil, NSError(domain: "MCPError", code: 0, userInfo: [NSLocalizedDescriptionKey: "MCP tool not found"]))
                }
                return
            }
            
            let retContent: String? = {
                for item in content {
                    switch item {
                    case .text(let text):
                        return text
                    case .image(let data, let mimeType, let metadata):
                        break
                    case .audio(let data, let mimeType):
                        break
                    case .resource(let uri, let mimeType, let text):
                        break
                    }
                }
                return nil
            }()
            
            guard let retContent else {
                DispatchQueue.main.async {
                    complete(nil, NSError(domain: "MCPError", code: 0, userInfo: [NSLocalizedDescriptionKey: "MCP tool return no text content"]))
                }
                return
            }
            
            DispatchQueue.main.async {
                complete(retContent, nil)
            }
        }
    }
}
