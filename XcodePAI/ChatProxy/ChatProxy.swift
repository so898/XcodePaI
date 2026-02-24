//
//  ChatProxy.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/8.
//

import Foundation
import Logger

/// `ChatProxy` is a singleton class responsible for managing a TCP server to proxy chat-related network communication.
/// It listens on a specified port, accepts client connections, and creates a tunnel (`ChatProxyTunnel`) for each connection to handle data transmission.
/// This proxy primarily acts as a bridge between the local application and a remote chat service, supporting HTTP keep-alive.
class ChatProxy {
    
    /// The shared singleton instance.
    static let shared = ChatProxy()
    
    /// The TCP server instance used to listen for and accept connections.
    private var server: TCPServer?
    
    /// List of currently active tunnel connections.
    private var tunnels = [ChatProxyTunnel]()
    
    /// Serial queue for thread-safe access to tunnels array
    private let tunnelsQueue = DispatchQueue(label: "com.xcodepai.chatproxy.tunnels")
    
    /// Initializes the `ChatProxy` instance and starts the server.
    init() {
        restart()
    }
    
    /// Restarts the TCP server:
    /// - Stops the currently running server (if any).
    /// - Creates and starts a new server instance on the configured port.
    func restart() {
        if let currentServer = server {
            currentServer.stop()
            server = nil
        }
        server = TCPServer(port: Configer.chatProxyPort, delegate: self)
        server?.start()
    }
    
    /// Determines whether an HTTP request should keep the connection alive.
    /// - Checks the "Connection" header in the HTTP request.
    /// - Returns `true` if the connection should be kept alive; otherwise, `false`.
    ///
    /// - Parameter request: The HTTP request to inspect.
    /// - Returns: Whether the connection should be kept alive.
    func shouldKeepAlive(_ request: HTTPRequest) -> Bool {
        // Keep connection based on the "Connection" header key.
        guard let connectionHeader = request.headers["Connection"] else { return false }
        return connectionHeader.lowercased() == "keep-alive"
    }
}

// MARK: - TCPServerDelegate Implementation

extension ChatProxy: TCPServerDelegate {
    /// Called when the server starts listening on the specified port.
    /// - Parameter port: The port number being listened on.
    func serverStartListen(port: Int) {
        Logger.network.info("TCP listen at port: \(port)")
    }
    
    /// Called when the server stops listening.
    /// - Parameter error: The error that occurred during stopping (if any).
    func serverStopListen(error: (any Error)?) {
        if let error {
            Logger.network.error("TCP stop listening: \(error.localizedDescription)")
        } else {
            Logger.network.info("TCP stop listening")
        }
    }
    
    /// Called when a new TCP connection is received.
    /// - Creates a `ChatProxyTunnel` for the new connection and adds it to the `tunnels` array.
    /// - Parameter connection: The newly established TCP connection.
    func serverDidReceive(connection: TCPConnection) {
        let tunnel = ChatProxyTunnel(connection, delegate: self)
        tunnelsQueue.async { [weak self] in
            self?.tunnels.append(tunnel)
        }
    }
}

// MARK: - ChatProxyTunnelDelegate Implementation

extension ChatProxy: ChatProxyTunnelDelegate {
    /// Called when a tunnel stops working.
    /// - Removes the stopped tunnel from the `tunnels` array.
    /// - Parameter tunnel: The tunnel instance that has stopped.
    func tunnelStoped(_ tunnel: ChatProxyTunnel) {
        tunnelsQueue.async { [weak self] in
            self?.tunnels.removeAll { $0 == tunnel }
        }
    }
}
