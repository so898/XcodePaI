//
//  ChatProxy.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/8.
//

import Foundation
import Logger

class ChatProxy {
    
    static let shared = ChatProxy()
    
    private var server: TCPServer?
    
    private var tunnels = [ChatProxyTunnel]()
    
    init() {
        restart()
    }
    
    func restart() {
        if let currentServer = server {
            currentServer.stop()
            server = nil
        }
        server = TCPServer(port: Configer.chatProxyPort, delegate: self)
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
        Logger.network.info("TCP listen at port: \(port)")
    }
    
    func serverStopListen(error: (any Error)?) {
        if let error {
            Logger.network.error("TCP stop listening: \(error.localizedDescription)")
        } else {
            Logger.network.info("TCP stop listening")
        }
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
