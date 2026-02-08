//
//  TCPConnection.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/10.
//

import Foundation
import Network
import Logger

protocol TCPConnectionDelegate: AnyObject {
    func connectionConnected(_ connection: TCPConnection)
    func connection(_ connection: TCPConnection, didReceiveData data: Data)
    func connection(_ connection: TCPConnection, didWrite data: Data, tag: Int?)
    func connection(_ connection: TCPConnection, didNotWrite error: Error, tag: Int?)
    func connection(_ connection: TCPConnection, closed error: Error?)
}

class TCPConnection {
    let connection: NWConnection
    private let queue = DispatchQueue(label: "server.connection")
    weak var delegate: TCPConnectionDelegate?
    
    init(_ connection: NWConnection) {
        self.connection = connection
    }
    
    func start() {
        // Do not check again
        setupHandlers()
        connection.start(queue: queue)
    }
    
    private func setupHandlers() {
        connection.stateUpdateHandler = {[weak self] newState in
            guard let `self` = self else {
                return
            }
            switch newState {
            case .setup:
                Logger.network.debug("Connection setup")
            case .waiting(_):
                Logger.network.debug("Connection waiting")
            case .preparing:
                Logger.network.debug("Connection preparing")
            case .ready:
                Logger.network.info("Connection ready")
                self.delegate?.connectionConnected(self)
                self.receiveData()
            case .failed(let error):
                Logger.network.error("Connection failed: \(error.localizedDescription)")
                self.cleanup(error)
            case .cancelled:
                Logger.network.info("Connection cancelled")
                self.cleanup(nil)
            @unknown default:
                fatalError()
            }
        }
    }
    
    func read() {
        receiveData()
    }
    
    func write(_ data: Data, tag: Int? = nil) {
        connection.send(content: data, completion: .contentProcessed({[weak self] error in
            guard let `self` = self else {
                return
            }
            if let error = error {
                self.delegate?.connection(self, didNotWrite: error, tag: tag)
                return
            }
            self.delegate?.connection(self, didWrite: data, tag: tag)
        }))
    }
    
    func stop() {
        self.queue.async {[weak self] in
            guard let `self` = self else { return }
            self.connection.cancel()
        }
    }
    
    func forceStop() {
        self.queue.async {[weak self] in
            guard let `self` = self else { return }
            self.cleanup()
        }
    }
    
    private func receiveData() {
        // Read data till connection close
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let `self` = self else { return }
            
            if let error = error {
                self.cleanup(error)
                return
            }
            
            if let data = data, data.count > 0 {
                self.delegate?.connection(self, didReceiveData: data)
            }
            
            // If there is more data, keep processing
            if isComplete {
                self.cleanup()
            } else {
                // Keep reading
                self.receiveData()
            }
        }
    }
    
    private func cleanup(_ error: Error? = nil) {
        delegate?.connection(self, closed: error)
        delegate = nil
        connection.cancel()
    }
}
