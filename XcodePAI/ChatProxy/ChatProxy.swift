//
//  ChatProxy.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/8.
//

import Foundation

class ChatProxy {
    static let shared = ChatProxy()
    
    private var server: ChunkedHTTPServer?
    init() {
        server = ChunkedHTTPServer(port: 50222, requestHandler: { request in
            print("Handling request: \(request.method) \(request.path)")
            
            // Create Response
            let response = HTTPResponse(
                headers: ["Content-Type": "text/plain"]
            )
            
            // Generate Chunk
            let chunks = [
                "Hello, ".data(using: .utf8)!,
                "this is a ".data(using: .utf8)!,
                "chunked response!".data(using: .utf8)!
            ]
//            response.contentChunks = chunks
            
            // Send response
            request.connection?.sendResponse(response: response)
            
            for chunk in chunks {
                request.connection?.sendChunk(chunk)
                sleep(5)
            }
            
            request.connection?.sendEndChunk()
            
            
            // Close Connection
            // Maybe after write complete
//            if !shouldKeepAlive(request) {
//                request.connection?.closeConnection()
//            }
        })
        server?.start()
    }
    
    func shouldKeepAlive(_ request: HTTPRequest) -> Bool {
        // keep connection with Connection header key
        guard let connectionHeader = request.headers["Connection"] else { return false }
        return connectionHeader.lowercased() == "keep-alive"
    }
}
