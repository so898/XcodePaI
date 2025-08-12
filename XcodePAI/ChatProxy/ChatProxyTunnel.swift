//
//  ChatProxyTunnel.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/10.
//

import Foundation

protocol ChatProxyTunnelDelegate {
    func tunnelStoped(_ tunnel: ChatProxyTunnel)
}

enum ChatProxyTunnelResponeType {
    case unknown
    case models
    case completions
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
        let models = [ChatProxyLLMModel(id: "XcodePaI", created: Date.currentTimeStamp())]
        
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
    
    private func writeServerErrorResponse() {
        responseType = .unknown
        connection?.writeResponse(HTTPResponse(statusCode: 500, statusMessage: "Server not supported."))
    }

    private var llmClient: LLMClient?
    private var hasThink: Bool?
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
        guard let jsonDict = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            writeServerErrorResponse()
            return
        }
        
        let originalRequest = LLMRequest(dict: jsonDict)
        originalRequest.model = "xxx"
        
        // Do LLM request to server, add MCP...
        hasThink = nil
        
        if let llmClient = llmClient {
            llmClient.stop()
        }
        
        llmClient = LLMClient(LLMServer(url: "xxx", privateKey: "sk-xxx"), delegate: self)
        llmClient?.request(originalRequest)
        
        responseType = .completions
        var response = HTTPResponse()
        response.chunked()
        connection?.writeResponse(response)
    }
}

// MARK: HTTPConnectionDelegate
extension ChatProxyTunnel: HTTPConnectionDelegate {
    func connection(_ connection: HTTPConnection, didReceiveRequest request: HTTPRequest) {
        print("Handling request: \(request.method) \(request.path)")
        
        if request.method == "GET", request.path.contains("/v1/models") {
            // Model Request
            responseType = .models
            
            var response = HTTPResponse()
            response.addContentLength(modelDataLength())
            connection.writeResponse(response)
        } else if request.method == "POST", request.path.contains("/v1/chat/completion"), let bodyData = request.body {
            receiveCompletionsRequest(body: bodyData)
        } else {
            writeServerErrorResponse()
        }
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
    }
    
    func connection(_ connection: HTTPConnection, didNotWrite error: any Error, tag: Int?) {
        
    }
    
    func connection(_ connection: HTTPConnection, closed error: (any Error)?) {
        delegate?.tunnelStoped(self)
    }
}

extension ChatProxyTunnel: LLMClientDelegate {
    func client(_ client: LLMClient, receivePart part: LLMAssistantMessage) {
        var response: LLMResponse?
        if hasThink == nil, let reason = part.reason {
            hasThink = true
            response = LLMResponse(id: id, model: "XcodePaI", object: "chat.completion.chunk", choices: [LLMResponseChoice(index: 0, finishReason: part.finishReason, isFullMessage: false, message: LLMResponseChoiceMessage(role: "assistant", content: "```think\n\n" + reason.replacingOccurrences(of: "```", with: "'''")))])
        } else if hasThink == true, let reason = part.reason {
            response = LLMResponse(id: id, model: "XcodePaI", object: "chat.completion.chunk", choices: [LLMResponseChoice(index: 0, finishReason: part.finishReason, isFullMessage: false, message: LLMResponseChoiceMessage(role: "assistant", content: reason.replacingOccurrences(of: "```", with: "'''")))])
        } else if hasThink == true, part.reason == nil, let content = part.content {
            response = LLMResponse(id: id, model: "XcodePaI", object: "chat.completion.chunk", choices: [LLMResponseChoice(index: 0, finishReason: part.finishReason, isFullMessage: false, message: LLMResponseChoiceMessage(role: "assistant", content: "\n\n~~EOT~~\n\n```\n\n" + content,))])
            hasThink = false
        } else if let content = part.content{
            response = LLMResponse(id: id, model: "XcodePaI", object: "chat.completion.chunk", choices: [LLMResponseChoice(index: 0, finishReason: part.finishReason, isFullMessage: false, message: LLMResponseChoiceMessage(role: "assistant", content: content))])
        }
        
        if let response = response, let json = try? JSONSerialization.data(withJSONObject: response.toDictionary()), let jsonStr = String(data: json, encoding: .utf8) {
            connection?.writeChunk(jsonStr + Constraint.DoubleLFString)
        }
    }
    
    func client(_ client: LLMClient, receiveMessage message: LLMAssistantMessage) {
        if let reason = message.reason {
            print("[R] \(reason)")
        }
        
        if let content = message.content {
            print("[C] \(content)")
        }
    }
    
    func client(_ client: LLMClient, receiveError errorInfo: [String : Any]) {
        connection?.writeChunk("[DONE]" + Constraint.DoubleLFString)
        connection?.writeEndChunk()
    }
    
    func client(_ client: LLMClient, closeWithComplete complete: Bool) {
        connection?.writeChunk("[DONE]" + Constraint.DoubleLFString)
        connection?.writeEndChunk()
    }
    
    
}

extension ChatProxyTunnel: Equatable {
    static func == (lhs: ChatProxyTunnel, rhs: ChatProxyTunnel) -> Bool {
        return lhs === rhs
    }
}
