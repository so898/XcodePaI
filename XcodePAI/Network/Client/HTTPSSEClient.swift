//
//  HTTPSSEClient.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/10.
//

import Foundation

protocol HTTPSSEClientDelegate {
    func client(_ client: HTTPSSEClient, receive chunk: String)
    func client(_ client: HTTPSSEClient, complete: (Result<Void, Error>))
}

class HTTPSSEClient: NSObject {
    
    private var sseDataBuffer = Data()
    private var sseTask: URLSessionDataTask?
    
    private var request: URLRequest?
    private var delegate: HTTPSSEClientDelegate?
    private let queue = DispatchQueue(label: "client.sse")
    
    init(url: String, headers: [String: Any]? = nil, body: Data?, delegate: HTTPSSEClientDelegate) {
        guard let url = URL(string: url) else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        headers?.forEach { key, value in
            if let value = value as? String {
                request.addValue(value, forHTTPHeaderField: key)
            } else if let value = value as? Int {
                request.addValue(String(value), forHTTPHeaderField: key)
            } else if let value = value as? Double {
                request.addValue(String(value), forHTTPHeaderField: key)
            }
        }
        self.request = request
        
        self.delegate = delegate
    }
    
    func start() {
        guard let request = request else {
            return
        }
        sseDataBuffer = Data()
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        sseTask = session.dataTask(with: request)
        sseTask?.resume()
    }
    
    func cancel() {
        sseTask?.cancel()
        sseTask = nil
    }
    
    private func cleanup() {
        queue.async { [weak self] in
            guard let `self` = self else {
                return
            }
            self.sseTask = nil
            self.sseDataBuffer = Data()
        }
    }
    
    private func receive(_ data: Data) {
        guard var chunk = String(data: data, encoding: .utf8) else {
            self.delegate?.client(self, complete: .failure(CocoaError(.validationInvalidDate, userInfo: ["message": "Parser chunk data fail"])))
            return
        }
        
        if chunk[..<chunk.index(chunk.startIndex, offsetBy: 5)] == "data:" {
            // SSE Mode
            // remove prefix `data: `
            chunk = String(chunk.suffix(chunk.count - 6))
        }
        
        queue.async { [weak self] in
            guard let `self` = self else {
                return
            }
            self.delegate?.client(self, receive: chunk)
        }
    }
}

// MARK: URLSessionDataDelegate for SSE handling
extension HTTPSSEClient: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        sseDataBuffer.append(data)
        
        // Process data chunks separated by double newline characters
        while let range = sseDataBuffer.range(of: Constraint.DoubleLF) {
            let chunkData = sseDataBuffer.subdata(in: 0..<range.lowerBound)
            sseDataBuffer.removeSubrange(0..<range.upperBound)
            
            if !chunkData.isEmpty {
                receive(data)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        queue.async { [weak self] in
            guard let `self` = self else {
                return
            }
            if let error = error {
                self.delegate?.client(self, complete: .failure(error))
            } else {
                // Process any remaining data
                let buffer = self.sseDataBuffer
                if !buffer.isEmpty {
                    receive(buffer)
                    self.sseDataBuffer = Data()
                }
                queue.async { [weak self] in
                    guard let `self` = self else {
                        return
                    }
                    self.delegate?.client(self, complete: .success(()))
                }
            }
            self.cleanup()
        }
    }
}
