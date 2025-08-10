//
//  HTTPConnection.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/10.
//

import Foundation

protocol HTTPConnectionDelegate {
    func connection(_ connection: HTTPConnection, didReceiveRequest request: HTTPRequest)
    func connection(_ connection: HTTPConnection, didSentResponse success: Bool)
    func connection(_ connection: HTTPConnection, didWrite tag: Int?)
    func connection(_ connection: HTTPConnection, didNotWrite error: Error, tag: Int?)
    func connection(_ connection: HTTPConnection, closed error: Error?)
}

struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    var body: Data? = nil
}

struct HTTPResponse {
    var statusCode: Int
    var statusMessage: String
    var headers: [String: String]
    
    init(
        statusCode: Int = 200,
        statusMessage: String = "OK",
        headers: [String: String] = [:],
    ) {
        self.statusCode = statusCode
        self.statusMessage = statusMessage
        self.headers = headers
    }
    
    mutating func addContentLength(_ length: Int) {
        headers["Content-Length"] = "\(length)"
    }
    
    mutating func chunked() {
        headers["Transfer-Encoding"] = "chunked"
    }
}

class HTTPConnection {
    private let connection: TCPConnection
    private let delegate: HTTPConnectionDelegate
    
    init(_ connection: TCPConnection, delegate: HTTPConnectionDelegate) {
        self.connection = connection
        self.delegate = delegate
        connection.start(self)
    }
    
    func read() {
        connection.read()
    }
    
    private var HTTPResponseWrited = false
    private let HTTPResponseWriteTag = 4887 // HTTP
    
    func writeResponse(_ response: HTTPResponse) {
        guard !HTTPResponseWrited else {
            return
        }
        // Send HTTP response header
        var headerString = "HTTP/1.1 \(response.statusCode) \(response.statusMessage)" + Constraint.CRLFString
        
        for (key, value) in response.headers {
            headerString += "\(key): \(value)" + Constraint.CRLFString
        }
        
        headerString += Constraint.CRLFString
        
        connection.write(Data(headerString.utf8), tag: HTTPResponseWriteTag)
    }
    
    func write(_ respString: String, tag: Int? = nil) {
        guard HTTPResponseWrited, let data = respString.data(using: .utf8) else {
            return
        }
        connection.write(data, tag: tag)
    }
    
    func stop() {
        connection.stop()
    }
    
    func forceStop() {
        connection.forceStop()
    }
    
    private var accumulatedData = Data()
    private var isHeaderComplete = false
    private var expectedBodyLength = 0
    private var currentRequest: HTTPRequest?
    
    private func processAccumulatedData() {
        guard !isHeaderComplete else {
            processRequestBody()
            return
        }
        
        // Find CRLFCRLF
        if let headerEndRange = accumulatedData.range(of: Constraint.DoubleCRLF) {
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
        let lines = headerString.components(separatedBy: Constraint.CRLFString)
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
            headers: headers
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
        self.delegate.connection(self, didReceiveRequest: request)
        
        // Reset status for the next request (keep-alive)
        currentRequest = nil
        isHeaderComplete = false
        expectedBodyLength = 0
        HTTPResponseWrited = false
        
        // Keep receiving data
        if accumulatedData.count > 0 {
            processAccumulatedData()
        }
    }
    
}

// MARK: Chunked
extension HTTPConnection {
    func writeChunk(_ chunk: String, tag: Int? = nil) {
        guard HTTPResponseWrited, let data = chunk.data(using: .utf8) else {
            return
        }
        let chunkSize = String(format: "%lx", data.count)
        let chunkHeader = Data("\(chunkSize)".utf8)
        let chunkData = chunkHeader + Constraint.CRLF + data + Constraint.CRLF
        connection.write(chunkData)
    }
    
    func writeEndChunk() {
        write("")
    }
}

// MARK: SSE
extension HTTPConnection {
    
}

// MARK: HTTPConnectionDelegate
extension HTTPConnection: TCPConnectionDelegate {
    func connectionConnected(_ connection: TCPConnection) {
        read()
    }
    
    func connection(_ connection: TCPConnection, didReceiveData data: Data) {
        accumulatedData.append(data)
        processAccumulatedData()
    }
    
    func connection(_ connection: TCPConnection, didWrite data: Data, tag: Int?) {
        if HTTPResponseWriteTag == tag {
            HTTPResponseWrited = true
            delegate.connection(self, didSentResponse: true)
            return
        }
        delegate.connection(self, didWrite: tag)
    }
    
    func connection(_ connection: TCPConnection, didNotWrite error: any Error, tag: Int?) {
        if HTTPResponseWriteTag == tag {
            HTTPResponseWrited = true
            delegate.connection(self, didSentResponse: false)
            return
        }
        delegate.connection(self, didNotWrite: error, tag: tag)
    }
    
    func connection(_ connection: TCPConnection, closed error: (any Error)?) {
        delegate.connection(self, closed: error)
    }
}
