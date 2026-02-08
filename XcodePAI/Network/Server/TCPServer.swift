//
//  TCPServer.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/10.
//

import Foundation
import Network
import Logger

protocol TCPServerDelegate {
    func serverStartListen(port: Int)
    func serverStopListen(error: Error?)
    
    func serverDidReceive(connection: TCPConnection)
}

class TCPServer {
    let port: UInt16
    private let listener: NWListener
    private let queue = DispatchQueue(label: "server.queue", attributes: .concurrent)
    private let connectionQueue = DispatchQueue(label: "connection.queue", attributes: .concurrent)
    
    private let delegate: TCPServerDelegate
        
    init(port: UInt16, delegate: TCPServerDelegate) {
        self.port = port
        self.delegate = delegate
        
        let parameters = NWParameters(tls: nil)
        parameters.allowLocalEndpointReuse = true
        parameters.allowFastOpen = true
        
        guard let listener = try? NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!) else {
            fatalError("Failed to create listener on port \(port)")
        }
        self.listener = listener
        
        listener.stateUpdateHandler = {[weak self] newState in
            guard let `self` = self else { return }
            switch newState {
            case .setup:
                Logger.network.debug("Server setup")
            case .waiting(_):
                Logger.network.debug("Server waiting")
            case .ready:
                Logger.network.info("Server ready")
                self.delegate.serverStartListen(port: Int(self.listener.port?.rawValue ?? 0))
            case .failed(let error):
                Logger.network.error("Server failed: \(error.localizedDescription)")
                self.delegate.serverStopListen(error: error)
            case .cancelled:
                Logger.network.info("Server cancelled")
                self.delegate.serverStopListen(error: nil)
            @unknown default:
                fatalError()
            }
        }
        
        // Process the connection
        listener.newConnectionHandler = { [weak self] connection in
            guard let `self` = self else { return }
            let tcpConnection = TCPConnection(connection)
            // start connection immediatly
            tcpConnection.start()
            self.delegate.serverDidReceive(connection: tcpConnection)
        }
    }
    
    func start() {
        listener.start(queue: queue)
        Logger.network.info("Server started on port \(port)")
    }
    
    func stop() {
        listener.cancel()
    }
}
