//
//  HTTPConnection.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/10.
//

import Foundation

protocol HTTPConnectionDelegate: AnyObject {
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
        headers: [String: String] = [:]
    ) {
        self.statusCode = statusCode
        self.statusMessage = statusMessage
        self.headers = headers
    }
    
    mutating func addContentLength(_ length: Int) {
        headers["Content-Length"] = "\(length)"
    }
    
    mutating func chunked() {
        headers["Connection"] = "keep-alive"
        headers["Content-Type"] = "text/event-stream"
        headers["Transfer-Encoding"] = "chunked"
    }
}

class HTTPConnection {
    private let connection: TCPConnection
    private weak var delegate: HTTPConnectionDelegate?
    
    init(_ connection: TCPConnection, delegate: HTTPConnectionDelegate) {
        self.connection = connection
        self.delegate = delegate
        connection.delegate = self
    }
    
    func read() {
        connection.read()
    }
    
    private var HTTPResponseWrited = false
    private let HTTPResponseWriteTag = 4887 // HTTP
    private let SSEWriteLastTag = 5278 // LAST
    
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
    
    func write(_ data: Data, tag: Int? = nil) {
        guard HTTPResponseWrited else {
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
            
            // Process request
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
        // Reset HTTP response status BEFORE handling request
        // This is critical for keep-alive connections where the previous response
        // has set HTTPResponseWrited = true, and we need to allow new response for new request
        HTTPResponseWrited = false
        
        self.delegate?.connection(self, didReceiveRequest: request)
        
        // Reset other status for the next request (keep-alive)
        currentRequest = nil
        isHeaderComplete = false
        expectedBodyLength = 0
        
        // Keep receiving data
        if accumulatedData.count > 0 {
            processAccumulatedData()
        } else {
            accumulatedData = Data()
        }
    }
    
}

// MARK: Chunked
extension HTTPConnection {
    func writeChunk(_ chunk: String, tag: Int? = nil) {
        guard HTTPResponseWrited else {
            return
        }
        guard let data = chunk.data(using: .utf8) else {
            return
        }
        let chunkSize = String(format: "%lx", data.count)
        let chunkHeader = Data("\(chunkSize)".utf8)
        let chunkData = chunkHeader + Constraint.CRLF + data + Constraint.CRLF
        connection.write(chunkData)
    }
    
    func writeEndChunk() {
        guard HTTPResponseWrited else {
            return
        }
        let chunkSize = String(format: "%lx", 0)
        let chunkHeader = Data("\(chunkSize)".utf8)
        let chunkData = chunkHeader + Constraint.DoubleCRLF
        connection.write(chunkData, tag: SSEWriteLastTag)
    }
}

// MARK: SSE
extension HTTPConnection {
    func writeSSEDict(_ dict: [String: Any], tag: Int? = nil) {
        if let json = try? JSONSerialization.data(withJSONObject: dict), let jsonStr = String(data: json, encoding: .utf8) {
            writeSSE(jsonStr, tag: tag)
        }
    }
    
    func writeSSEString(_ string: String, tag: Int? = nil) {
        writeSSE(string, tag: tag)
    }
    
    func writeSSE(_ value: String, tag: Int? = nil) {
        writeChunk("data: " + value + Constraint.DoubleLFString, tag: tag)
    }
    
    func writeSSEEvent(event: String?, data: String, tag: Int? = nil) {
        writeSSEEventWithId(id: nil, event: event, data: data, tag: tag)
    }
    
    func writeSSEEventWithId(id: String?, event: String?, data: String, tag: Int? = nil) {
        var output = ""
        // Add SSE message ID for resumability support
        if let id = id {
            output += "id: \(id)\n"
        }
        if let event = event {
            output += "event: \(event)\n"
        }
        output += "data: \(data)" + Constraint.DoubleLFString
        writeChunk(output, tag: tag)
    }
    
    func writeSSEComplete() {
        writeChunk("data: [DONE]" + Constraint.DoubleLFString)
        writeEndChunk()
    }
}

// MARK: HTTPConnectionDelegate
extension HTTPConnection: TCPConnectionDelegate {
    func connectionConnected(_ connection: TCPConnection) {
        // Read data after connection established
        read()
    }
    
    func connection(_ connection: TCPConnection, didReceiveData data: Data) {
        accumulatedData.append(data)
        processAccumulatedData()
    }
    
    func connection(_ connection: TCPConnection, didWrite data: Data, tag: Int?) {
        if HTTPResponseWriteTag == tag {
            HTTPResponseWrited = true
            delegate?.connection(self, didSentResponse: true)
            return
        }
        if SSEWriteLastTag == tag {
            stop()
            return
        }
        delegate?.connection(self, didWrite: tag)
    }
    
    func connection(_ connection: TCPConnection, didNotWrite error: any Error, tag: Int?) {
        if HTTPResponseWriteTag == tag {
            HTTPResponseWrited = true
            delegate?.connection(self, didSentResponse: false)
            return
        }
        delegate?.connection(self, didNotWrite: error, tag: tag)
    }
    
    func connection(_ connection: TCPConnection, closed error: (any Error)?) {
        delegate?.connection(self, closed: error)
    }
}
