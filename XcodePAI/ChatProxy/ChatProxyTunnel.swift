//
//  ChatProxyTunnel.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/10.
//

import Foundation
import Logger

protocol ChatProxyTunnelDelegate {
    func tunnelStoped(_ tunnel: ChatProxyTunnel)
}

protocol ChatProxyBridgeDelegate {
    func bridge(connected success: Bool)
    func bridge(write dict: [String: Any])
    func bridge(write string: String)
    func bridge(event: String?, data: String)
    func bridgeWriteEndChunk()
}

enum ChatProxyTunnelResponeType {
    case unknown
    case models
    case completions
    case mcp     // Standard MCP JSON response
    case mcpSSE  // SSE stream for MCP notifications (via GET request)
    case error
}

class ChatProxyTunnel {
    private var id = UUID().uuidString
    private var connection: HTTPConnection?
    private var delegate: ChatProxyTunnelDelegate?
    
    init(_ connection: TCPConnection, delegate: ChatProxyTunnelDelegate) {
        self.connection = HTTPConnection(connection, delegate: self)
        self.delegate = delegate
    }
    
    private var responseType = ChatProxyTunnelResponeType.unknown
    
    private let modelListTag = 66335
    
    private var _modelListString: String?
    private lazy var modelListString: String = {
        if let modelListString = _modelListString {
            return modelListString
        }
        let models = StorageManager.shared.getChatProxyModels()
        
        var modelsList = [Any]()
        for model in models {
            modelsList.append(model.toDictionary())
        }
        let ret = ["data": modelsList]
        
        if let json = try? JSONSerialization.data(withJSONObject: ret), let jsonString = String(data: json, encoding: .utf8) {
            _modelListString = jsonString
        }
        return _modelListString ?? ""
    }()
    
    private let mcpResponseBodyTag = 66336
    private var mcpResponseBodyData: Data?
    private var mcpSessionId: String?       // Session ID for MCP
    private var mcpSSEActive = false        // Whether SSE stream is active for notifications
    private var mcpClientRegistered = false // Whether registered as MCP client for notifications
    private var mcpInitialized = false      // Whether client has completed initialization
    private var sseMessageId: Int = 0       // SSE message ID counter for notifications
    
    private func writeServerErrorResponse() {
        responseType = .error
        connection?.writeResponse(HTTPResponse(statusCode: 500, statusMessage: "Server not supported."))
    }
    
    private lazy var bridge: ChatProxyBridge = {
        let bridge = ChatProxyBridge(id: id, delegate: self)
        return bridge
    }()
    
    private lazy var agenticBridge: ChatProxyCodexBridge = {
        let bridge = ChatProxyCodexBridge(id: id, delegate: self)
        return bridge
    }()
    
    private lazy var claudeBridge: ChatProxyClaudeBridge = {
        let bridge = ChatProxyClaudeBridge(id: id, delegate: self)
        return bridge
    }()
}

// MARK: Models List Response
extension ChatProxyTunnel{
    func modelDataLength() -> Int {
        if let data = modelListString.data(using: .utf8) {
            return data.count
        }
        return 0
    }
}

// MARK: Completions Response
extension ChatProxyTunnel{
    func receiveCompletionsRequest(body: Data) {
        bridge.receiveRequestData(body)
    }
}

// MARK: Responses
extension ChatProxyTunnel{
    func receiveResponsesRequest(body: Data) {
        agenticBridge.receiveRequestData(body)
    }
}

// MARK: Messages Response
extension ChatProxyTunnel{
    func receiveMessagesRequest(body: Data) {
        claudeBridge.receiveRequestData(body)
    }
}

// MARK: HTTPConnectionDelegate
extension ChatProxyTunnel: HTTPConnectionDelegate {
    func connection(_ connection: HTTPConnection, didReceiveRequest request: HTTPRequest) {
        if request.method == "GET", request.path.contains("/v1/models") {
            // Model Request
            responseType = .models
            
            var response = HTTPResponse()
            response.addContentLength(modelDataLength())
            connection.writeResponse(response)
        } else if request.method == "POST", request.path.contains("/v1/chat/completion"), let bodyData = request.body {
            receiveCompletionsRequest(body: bodyData)
        } else if request.method == "POST", request.path.contains("/v1/responses"), let bodyData = request.body {
            receiveResponsesRequest(body: bodyData)
        } else if request.method == "POST", request.path.contains("/v1/messages"), let bodyData = request.body {
            receiveMessagesRequest(body: bodyData)
        } else if request.path.contains("/mcp") {
            // MCP endpoint - supports both POST and GET per Streamable HTTP spec
            handleMCPEndpoint(request: request, connection: connection)
        } else {
            writeServerErrorResponse()
        }
    }
    
    private func handleMCPEndpoint(request: HTTPRequest, connection: HTTPConnection) {
        // Extract session ID from header if present
        if let sessionId = request.headers["Mcp-Session-Id"] ?? request.headers["mcp-session-id"] {
            mcpSessionId = sessionId
            Logger.mcp.info("MCP session ID from header: \(sessionId)")
        }
        
        if request.method == "POST" {
            // POST: Send JSON-RPC messages
            if let bodyData = request.body {
                receiveMCPRequest(body: bodyData)
            } else {
                writeMCPErrorResponse(statusCode: 400, message: "Empty request body")
            }
        } else if request.method == "GET" {
            // GET: Open SSE stream for server-to-client notifications
            startMCPSSEStream(connection: connection)
        } else {
            writeServerErrorResponse()
        }
    }
    
    /// Start SSE stream for server-to-client notifications (via GET request)
    private func startMCPSSEStream(connection: HTTPConnection) {
        responseType = .mcpSSE
        mcpSSEActive = true
        
        Logger.mcp.info("Starting MCP SSE stream, sessionId: \(mcpSessionId ?? "nil")")
        
        // Send SSE response headers
        var headers: [String: String] = [
            "Content-Type": "text/event-stream",
            "Cache-Control": "no-cache",
            "Connection": "keep-alive"
        ]
        
        // Check if client provided session ID to associate with existing session
        // This allows GET SSE stream to receive notifications for POST requests in same session
        if let sessionId = mcpSessionId {
            headers["Mcp-Session-Id"] = sessionId
            MCPServer.shared.registerSession(sessionId, client: self)
            mcpClientRegistered = true
            Logger.mcp.info("MCP SSE stream registered for session: \(sessionId)")
        } else {
            Logger.mcp.info("MCP SSE stream started without session ID - cannot receive notifications")
        }
        
        var response = HTTPResponse(headers: headers)
        response.chunked()
        connection.writeResponse(response)
    }
    
    func connection(_ connection: HTTPConnection, didSentResponse success: Bool) {
        guard success else {
            connection.stop()
            return
        }
        
        switch responseType {
        case .models:
            connection.write(modelListString, tag: modelListTag)
        case .completions:
            break
        case .mcp:
            // For MCP: write body if exists, otherwise just continue reading
            if let mcpResponseBodyData {
                connection.write(mcpResponseBodyData, tag: mcpResponseBodyTag)
            } else {
                // 202 Accepted with no body - continue reading for more requests
                connection.read()
            }
        case .mcpSSE:
            // SSE stream started, keep connection open for notifications
            break
        case .error:
            break
        case .unknown:
            connection.stop()
        @unknown default:
            fatalError()
        }
    }
    
    func connection(_ connection: HTTPConnection, didWrite tag: Int?) {
        if modelListTag == tag {
            connection.stop()
            return
        }
        // For MCP responses, keep connection alive to allow subsequent requests
        if mcpResponseBodyTag == tag {
            connection.read()
            return
        }
    }
    
    func connection(_ connection: HTTPConnection, didNotWrite error: any Error, tag: Int?) {
        
    }
    
    func connection(_ connection: HTTPConnection, closed error: (any Error)?) {
        // Cleanup MCP resources
        if mcpClientRegistered, let sessionId = mcpSessionId {
            MCPServer.shared.unregisterSession(sessionId)
        }
        mcpSSEActive = false
        mcpClientRegistered = false
        
        bridge.stop()
        delegate?.tunnelStoped(self)
    }
}

// MARK: - MCPServerClientDelegate
extension ChatProxyTunnel: MCPServerClientDelegate {
    func mcpServerToolsDidChange() {
        // Check if we can send notifications
        // Either through active SSE stream OR through registered POST connection
        guard mcpClientRegistered else {
            Logger.mcp.info("MCP tools changed but client not registered, skipping notification")
            return
        }
        
        if mcpSSEActive {
            // Send via SSE stream
            Logger.mcp.info("MCP tools changed, sending notifications/tools/list_changed via SSE")
            sendMCPNotification(method: "notifications/tools/list_changed")
            
            // WORKAROUND: Codex doesn't handle notifications/tools/list_changed
            // (see https://github.com/openai/codex/issues/10105)
            // Close SSE stream to force Codex to reconnect and re-fetch tool list
            Logger.mcp.info("MCP closing SSE stream to force client reconnect and tool list refresh")
            closeMCPSSEStream()
        } else {
            // For POST connections, we cannot push notifications directly
            // The client should poll or establish GET SSE stream
            Logger.mcp.info("MCP tools changed but no active SSE stream (mcpSSEActive=false), notification pending")
            // Store pending notification for next request, or client should use GET /mcp for SSE
        }
    }
    
    private func sendMCPNotification(method: String) {
        let notification: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: notification),
           var jsonString = String(data: jsonData, encoding: .utf8) {
            // Remove escaped slashes (\/) that JSONSerialization adds
            jsonString = jsonString.replacingOccurrences(of: "\\/", with: "/")
            
            // Send as SSE event with explicit event type
            // Some clients require 'event: message' line
            // Format: event: message\ndata: <json>\n\n
            Logger.mcp.info("MCP sending SSE notification: \(jsonString)")
            connection?.writeSSEEvent(event: "message", data: jsonString)
        } else {
            Logger.mcp.error("MCP failed to serialize notification: \(method)")
        }
    }
    
    private func closeMCPSSEStream() {
        // End chunked transfer encoding and close connection
        connection?.writeEndChunk()
        
        // Give client a moment to receive the end chunk before closing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            // Unregister session before closing
            if let sessionId = self.mcpSessionId {
                MCPServer.shared.unregisterSession(sessionId)
            }
            
            // Reset SSE state
            self.mcpSSEActive = false
            self.mcpClientRegistered = false
            
            // Close the connection
            self.connection?.stop()
        }
    }
}

// MARK: MCPServer
extension ChatProxyTunnel {
    
    func receiveMCPRequest(body: Data) {
        if let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            responseType = .mcp
            handleJSONRPCRequest(json)
        } else {
            // Invalid JSON - return 400 Bad Request
            writeMCPErrorResponse(statusCode: 400, message: "Invalid JSON")
        }
    }
    
    private func handleJSONRPCRequest(_ json: [String: Any]) {
        guard let method = json["method"] as? String else {
            writeMCPErrorResponse(statusCode: 400, message: "Missing method")
            return
        }
        
        // JSON-RPC id - nil for notifications
        let id = json["id"]
        let params = json["params"] as? [String: Any] ?? [:]
        
        // Check if this is a notification (no id field)
        let isNotification = id == nil
        
        // Generate session ID on initialize
        if method == "initialize" && mcpSessionId == nil {
            mcpSessionId = UUID().uuidString
        }
        
        // After notifications/initialized, register session for future notifications
        // Per MCP spec: notifications require 202 Accepted response, NOT SSE stream
        // SSE stream should only be established via separate GET request
        if method == "notifications/initialized" {
            mcpInitialized = true
            if let sessionId = mcpSessionId {
                Logger.mcp.info("MCP notifications/initialized received for session: \(sessionId), returning 202 and registering session")
                // Register session to receive notifications when SSE stream is established
                MCPServer.shared.registerSession(sessionId, client: self)
                mcpClientRegistered = true
            } else {
                Logger.mcp.info("MCP notifications/initialized received without session ID, returning 202")
            }
            // Always return 202 Accepted for notifications per MCP spec
            // Keep connection open for subsequent requests
            writeMCP202Accepted()
            return
        }
        
        MCPServer.shared.handleRequest(method: method, params: params, id: id) {[weak self] result in
            guard let self = self else { return }
            
            // Per MCP Streamable HTTP spec:
            // - For notifications: return 202 Accepted with no body
            // - For requests: return JSON-RPC response with 200 OK
            
            if isNotification {
                self.writeMCP202Accepted()
            } else {
                // Build JSON-RPC response
                var response: [String: Any] = [
                    "jsonrpc": "2.0"
                ]
                
                if let id = id {
                    response["id"] = id
                }
                
                if let result = result {
                    response["result"] = result
                } else {
                    // Should not happen for requests, but handle gracefully
                    response["result"] = [:]
                }
                
                // Include session ID in initialize response
                let includeSessionId = (method == "initialize")
                self.writeMCPResponse(response, includeSessionId: includeSessionId)
            }
        }
    }
    
    /// Start SSE stream for notifications after client initialized
    /// This converts the POST connection to SSE mode for server-to-client notifications
    private func startMCPNotificationSSE(sessionId: String) {
        responseType = .mcpSSE
        mcpSSEActive = true
        mcpClientRegistered = true
        
        // Register for tool change notifications
        MCPServer.shared.registerSession(sessionId, client: self)
        Logger.mcp.info("MCP SSE stream started for session: \(sessionId), registered for tool change notifications")
        
        // Send SSE response headers
        let headers: [String: String] = [
            "Content-Type": "text/event-stream",
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "Mcp-Session-Id": sessionId
        ]
        
        var response = HTTPResponse(headers: headers)
        response.chunked()
        connection?.writeResponse(response)
    }
    
    /// Return 202 Accepted for notifications (per MCP Streamable HTTP spec)
    private func writeMCP202Accepted() {
        let response = HTTPResponse(
            statusCode: 202,
            statusMessage: "Accepted",
            headers: [
                "Content-Length": "0",
                "Connection": "keep-alive"
            ]
        )
        mcpResponseBodyData = nil
        connection?.writeResponse(response)
    }
    
    /// Return error response
    private func writeMCPErrorResponse(statusCode: Int, message: String) {
        let errorResponse: [String: Any] = [
            "jsonrpc": "2.0",
            "error": [
                "code": -32600,
                "message": message
            ]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: errorResponse) {
            mcpResponseBodyData = jsonData
            var response = HTTPResponse(
                statusCode: statusCode,
                statusMessage: "Bad Request",
                headers: ["Content-Type": "application/json"]
            )
            response.addContentLength(jsonData.count)
            connection?.writeResponse(response)
        }
    }
    
    func writeMCPResponse(_ response: [String: Any], includeSessionId: Bool = false) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: response)
            mcpResponseBodyData = jsonData
            
            var headers: [String: String] = [
                "Content-Type": "application/json",
                "Connection": "keep-alive"
            ]
            
            // Add session ID header for initialize response
            if includeSessionId, let sessionId = mcpSessionId {
                headers["Mcp-Session-Id"] = sessionId
            }
            
            var httpResponse = HTTPResponse(headers: headers)
            httpResponse.addContentLength(jsonData.count)
            connection?.writeResponse(httpResponse)
        } catch {
            Logger.mcp.error("Failed to serialize MCP response: \(error.localizedDescription)")
        }
    }
}

// MARK: ChatProxyBridgeDelegate
extension ChatProxyTunnel: ChatProxyBridgeDelegate {
    
    func bridge(connected success: Bool) {
        if success {
            responseType = .completions
            var response = HTTPResponse()
            response.chunked()
            connection?.writeResponse(response)
        } else {
            writeServerErrorResponse()
            connection?.stop()
        }
    }
    
    func bridge(write dict: [String : Any]) {
        connection?.writeSSEDict(dict)
    }
    
    func bridge(write string: String) {
        connection?.writeSSEString(string)
    }
    
    func bridge(event: String?, data: String) {
        connection?.writeSSEEvent(event: event, data: data)
    }
    
    func bridgeWriteEndChunk() {
        connection?.writeSSEComplete()
    }
    
}

extension ChatProxyTunnel: Equatable {
    static func == (lhs: ChatProxyTunnel, rhs: ChatProxyTunnel) -> Bool {
        return lhs === rhs
    }
}
