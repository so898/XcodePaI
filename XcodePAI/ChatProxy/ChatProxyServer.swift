//
//  ChatProxyServer.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/8.
//

import Foundation
import Network

class ChunkedHTTPServer {
    let port: UInt16
    private let listener: NWListener
    private let queue = DispatchQueue(label: "server.queue", attributes: .concurrent)
    private let connectionQueue = DispatchQueue(label: "connection.queue", attributes: .concurrent)
    private let requestHandler: (HTTPRequest) -> Void
    
    private var connections = [HTTPConnectionHandler]()
    
    init(port: UInt16, requestHandler: @escaping (HTTPRequest) -> Void) {
        self.port = port
        self.requestHandler = requestHandler
        
        let parameters = NWParameters(tls: nil)
        parameters.allowLocalEndpointReuse = true
        parameters.allowFastOpen = true
        
        guard let listener = try? NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!) else {
            fatalError("Failed to create listener on port \(port)")
        }
        self.listener = listener
        
        listener.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }
    }
    
    func start() {
        listener.start(queue: queue)
        print("Server started on port \(port)")
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        let connectionID = UUID().uuidString
        print("New connection: \(connectionID)")
        
        connectionQueue.async { [weak self] in
            let requestHandler = HTTPConnectionHandler(
                connection: connection,
                connectionID: connectionID,
                requestHandler: self?.requestHandler
            )
            self?.connections.append(requestHandler)
            requestHandler.start()
        }
        
        connection.start(queue: .global())
    }
}

class HTTPConnectionHandler {
    let connection: NWConnection
    let connectionID: String
    let requestHandler: ((HTTPRequest) -> Void)?
    
    private var accumulatedData = Data()
    private var isHeaderComplete = false
    private var expectedBodyLength = 0
    private var currentRequest: HTTPRequest?
    
    init(connection: NWConnection, connectionID: String, requestHandler: ((HTTPRequest) -> Void)?) {
        self.connection = connection
        self.connectionID = connectionID
        self.requestHandler = requestHandler
    }
    
    func start() {
        receiveData()
    }
    
    private func receiveData() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let data = data, !data.isEmpty {
                self.accumulatedData.append(data)
                self.processAccumulatedData()
            }
            
            if let error = error {
                print("Connection \(self.connectionID) error: \(error)")
                self.cleanup()
                return
            }
            
            if !isComplete {
                self.receiveData()
            } else {
                self.cleanup()
            }
        }
    }
    
    private func processAccumulatedData() {
        guard !isHeaderComplete else {
            processRequestBody()
            return
        }
        
        // Find CRLFCRLF
        if let headerEndRange = accumulatedData.range(of: Data("\r\n\r\n".utf8)) {
            isHeaderComplete = true
            
            // Parser header
            let headerData = accumulatedData.subdata(in: 0..<headerEndRange.upperBound)
            if let headerString = String(data: headerData, encoding: .utf8) {
                currentRequest = parseHeaders(headerString)
            }
            
            // Remove header data
            accumulatedData.removeSubrange(0..<headerEndRange.upperBound)
            
            // Process reqeust
            if accumulatedData.count > 0 {
                processRequestBody()
            } else if expectedBodyLength == 0, let currentRequest = currentRequest {
                // No body, just do request
                handleFullRequest(currentRequest)
            }
        }
    }
    
    private func parseHeaders(_ headerString: String) -> HTTPRequest {
        let lines = headerString.components(separatedBy: "\r\n")
        var method = "GET"
        var path = "/"
        
        // Parser request line
        if let requestLine = lines.first {
            let components = requestLine.split(separator: " ")
            if components.count >= 2 {
                method = String(components[0])
                path = String(components[1])
            }
        }
        
        // Anlysis header
        var headers = [String: String]()
        for line in lines.dropFirst() {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
                
                // Get Content-Length with POST request
                // Need check post?
                if key.lowercased() == "content-length", let length = Int(value) {
                    expectedBodyLength = length
                }
            }
        }
        
        return HTTPRequest(
            method: method,
            path: path,
            headers: headers,
            body: Data(),
            connection: self
        )
    }
    
    private func processRequestBody() {
        guard var request = currentRequest else { return }
        
        // Check body received complete or not
        if accumulatedData.count >= expectedBodyLength {
            let bodyData = accumulatedData.prefix(expectedBodyLength)
            request.body = bodyData
            accumulatedData.removeFirst(expectedBodyLength)
            
            // Process full request
            handleFullRequest(request)
        }
    }
    
    private func handleFullRequest(_ request: HTTPRequest) {
        // Process request in independent thread
        DispatchQueue.global().async { [weak self] in
            self?.requestHandler?(request)
        }
        
        // Reset status for the next request (keep-alive)
        currentRequest = nil
        isHeaderComplete = false
        expectedBodyLength = 0
        
        // Keep receiving data
        if accumulatedData.count > 0 {
            processAccumulatedData()
        }
    }
    
    func sendResponse(response: HTTPResponse) {
        // Send HTTP response header
        var headerString = "HTTP/1.1 \(response.statusCode) \(response.statusMessage)\r\n"
        headerString += "Transfer-Encoding: chunked\r\n"
        
        for (key, value) in response.headers {
            headerString += "\(key): \(value)\r\n"
        }
        
        headerString += "\r\n"
        
        sendData(Data(headerString.utf8))
    }
    
    func sendChunk(_ data: Data) {
        let chunkSize = String(format: "%lx", data.count)
        let chunkHeader = Data("\(chunkSize)\r\n".utf8)
        let chunkData = chunkHeader + data + Data("\r\n".utf8)
        sendData(chunkData)
    }
    
    func sendEndChunk() {
        sendData(Data("0\r\n\r\n".utf8))
    }
    
    private func sendData(_ data: Data) {
        connection.send(content: data, completion: .contentProcessed({ _ in }))
    }
    
    func closeConnection() {
        cleanup()
    }
    
    private func cleanup() {
        connection.cancel()
        print("Connection \(connectionID) closed")
    }
}

struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    var body: Data
    weak var connection: HTTPConnectionHandler?
}

struct HTTPResponse {
    var statusCode: Int
    var statusMessage: String
    var headers: [String: String]
    var contentChunks: [Data]
    
    init(
        statusCode: Int = 200,
        statusMessage: String = "OK",
        headers: [String: String] = [:],
        contentChunks: [Data] = []
    ) {
        self.statusCode = statusCode
        self.statusMessage = statusMessage
        self.headers = headers
        self.contentChunks = contentChunks
    }
}

