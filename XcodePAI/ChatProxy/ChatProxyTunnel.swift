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
        print("Handling request: \(request.method) \(request.path)")
        
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
    }
    
    func connection(_ connection: HTTPConnection, didNotWrite error: any Error, tag: Int?) {
        
    }
    
    func connection(_ connection: HTTPConnection, closed error: (any Error)?) {
        bridge.stop()
        delegate?.tunnelStoped(self)
    }
}

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
