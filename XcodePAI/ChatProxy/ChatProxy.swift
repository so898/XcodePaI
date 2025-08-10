//
//  ChatProxy.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/8.
//

import Foundation

class ChatProxy {
    
    static let shared = ChatProxy()
    
    private var server: TCPServer?
    
    private var tunnels = [ChatProxyTunnel]()
    
    init() {
        server = TCPServer(port: 50222, delegate: self)
        server?.start()
    }
    
    func shouldKeepAlive(_ request: HTTPRequest) -> Bool {
        // keep connection with Connection header key
        guard let connectionHeader = request.headers["Connection"] else { return false }
        return connectionHeader.lowercased() == "keep-alive"
    }
}

extension ChatProxy: TCPServerDelegate {
    func serverStartListen(port: Int) {
        print("TCP listen at port: \(port)")
    }
    
    func serverStopListen(error: (any Error)?) {
        print("TCP stop listening, \(String(describing: error))")
    }
    
    func serverDidReceive(connection: TCPConnection) {
        tunnels.append(ChatProxyTunnel(connection, delegate: self))
    }
}

extension ChatProxy: ChatProxyTunnelDelegate {
    func tunnelStoped(_ tunnel: ChatProxyTunnel) {
        tunnels.removeAll{$0 == tunnel}
    }
}
