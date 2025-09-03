import Foundation

/// Inter-process communication error types
public enum IPCWormholeError: Error, LocalizedError {
    case timeout
    case serializationError(Error)
    case invalidResponse
    case groupContainerNotFound
    
    public var errorDescription: String? {
        switch self {
        case .timeout:
            return "Operation timeout"
        case .serializationError(let error):
            return "Serialization error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response"
        case .groupContainerNotFound:
            return "Group container not found"
        }
    }
}

/// Inter-process communication class, designed based on MMWormhole
public class IPCWormhole: NSObject, @unchecked Sendable {
    private let groupID: String
    private let directoryURL: URL
    private var listeners: [String: Any] = [:]
    private var pendingReplies: [String: Any] = [:]
    private let serialQueue = DispatchQueue(label: "com.ipcwormhole.serial")
    private var filePresenter: IPCFilePresenter?
    private let operationQueue = OperationQueue()
    
    // Unique process instance identifier to prevent self-consumption
    private let instanceID: String
    private var sentMessageIDs: Set<String> = []
    private let maxSentMessageIDsCache = 1000
    
    // Performance optimization: cache processed files to avoid duplicate processing
    private var processedFiles: Set<String> = []
    private let maxProcessedFilesCache = 1000
    
    // Debounce handling: avoid frequent file system events
    private var debounceTimer: DispatchSourceTimer?
    private let debounceInterval: TimeInterval = 0.05 // 50ms debounce
    
    // Fallback polling mechanism: ensure cross-app file changes can be detected
    private var fallbackTimer: DispatchSourceTimer?
    private var isMonitoring = false
    private let fallbackInterval: TimeInterval = 0.2 // 200ms polling interval
    
    /// Initialize inter-process communication class
    /// - Parameter groupID: App Group identifier
    public init(groupID: String) throws {
        self.groupID = groupID
        
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            throw IPCWormholeError.groupContainerNotFound
        }
        
        self.directoryURL = containerURL.appendingPathComponent("IPCWormhole")
        
        // Generate unique process instance identifier to prevent self-consumption
        self.instanceID = UUID().uuidString
        
        // Configure operation queue
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.name = "com.ipcwormhole.filepresenter"
        
        super.init()
        
        // Ensure directory exists
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        
        // Start monitoring
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    /// Send message (no reply)
    /// - Parameters:
    ///   - message: Message to send
    ///   - identifier: Message identifier
    public func sendMessage<T: Codable & Sendable>(_ message: T, identifier: String) {
        serialQueue.async { [weak self] in
            self?._sendMessage(message, identifier: identifier)
        }
    }
    
    /// Send message and wait for reply (callback style)
    /// - Parameters:
    ///   - message: Message to send
    ///   - identifier: Message identifier
    ///   - replyTimeout: Reply timeout duration
    ///   - completion: Completion callback
    public func sendMessageWithReply<T: Codable & Sendable, R: Codable & Sendable>(
        message: T,
        identifier: String,
        replyTimeout: TimeInterval = 10.0,
        completion: @Sendable @escaping (Result<R, Error>) -> Void
    ) {
        serialQueue.async { [weak self] in
            self?._sendMessageWithReply(
                message: message,
                identifier: identifier,
                replyTimeout: replyTimeout,
                completion: completion
            )
        }
    }
    
    /// Send message and wait for reply (async/await style)
    /// - Parameters:
    ///   - message: Message to send
    ///   - identifier: Message identifier
    ///   - replyTimeout: Reply timeout duration
    /// - Returns: Reply message
    public func sendMessageWithReply<T: Codable & Sendable, R: Codable & Sendable>(
        message: T,
        identifier: String,
        replyTimeout: TimeInterval = 10.0
    ) async throws -> R {
        return try await withUnsafeThrowingContinuation { continuation in
            sendMessageWithReply(
                message: message,
                identifier: identifier,
                replyTimeout: replyTimeout
            ) { (result: Result<R, Error>) in
                continuation.resume(with: result)
            }
        }
    }
    
    /// Listen for messages with specific identifier
    /// - Parameters:
    ///   - identifier: Message identifier
    ///   - listener: Message listener, second parameter is reply function
    public func listenMessage<T: Codable & Sendable>(
        for identifier: String,
        listener: @escaping (T, @escaping (Any?) -> Void) -> Void
    ) {
        serialQueue.async { [weak self] in
            let messageListener = MessageListener<T>(handler: listener)
            self?.listeners[identifier] = messageListener
        }
    }
    
    // MARK: - Private Methods
    
    private func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        // Strategy 1: Try using NSFilePresenter
        setupFilePresenterMonitoring()
        
        // Strategy 2: Always use polling as fallback to ensure cross-app reliability
        setupFallbackPolling()
        
        // Process existing files
        serialQueue.async { [weak self] in
            self?.handleFileSystemEvent()
        }
    }
    
    private func setupFilePresenterMonitoring() {
        guard filePresenter == nil else { return }
        
        // Create NSFilePresenter
        filePresenter = IPCFilePresenter(directoryURL: directoryURL) { [weak self] in
            self?.scheduleFileSystemEventHandling()
        }
        
        // Register on main thread
        DispatchQueue.main.async { [weak self] in
            guard let presenter = self?.filePresenter else { return }
            NSFileCoordinator.addFilePresenter(presenter)
        }
    }
    
    private func setupFallbackPolling() {
        fallbackTimer = DispatchSource.makeTimerSource(queue: serialQueue)
        fallbackTimer?.schedule(deadline: .now() + fallbackInterval, repeating: fallbackInterval)
        fallbackTimer?.setEventHandler { [weak self] in
            self?.handleFileSystemEvent()
        }
        fallbackTimer?.resume()
    }
    
    private func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        
        // Cancel debounce timer
        debounceTimer?.cancel()
        debounceTimer = nil
        
        // Stop fallback polling
        fallbackTimer?.cancel()
        fallbackTimer = nil
        
        // Remove file presenter on main thread
        if let presenter = filePresenter {
            DispatchQueue.main.async {
                NSFileCoordinator.removeFilePresenter(presenter)
            }
            filePresenter = nil
        }
    }
    
    /// Debounced file system event handling
    private func scheduleFileSystemEventHandling() {
        // Cancel previous timer
        debounceTimer?.cancel()
        
        // Create new timer
        debounceTimer = DispatchSource.makeTimerSource(queue: serialQueue)
        debounceTimer?.schedule(deadline: .now() + debounceInterval)
        debounceTimer?.setEventHandler { [weak self] in
            self?.handleFileSystemEvent()
        }
        debounceTimer?.resume()
    }
    
    private func _sendMessage<T: Codable>(_ message: T, identifier: String) {
        do {
            let messageID = UUID().uuidString
            let envelope = MessageEnvelope(
                id: messageID,
                identifier: identifier,
                data: try JSONEncoder().encode(message),
                timestamp: Date(),
                requiresReply: false,
                senderID: instanceID
            )
            
            // Record sent message ID to prevent self-consumption
            sentMessageIDs.insert(messageID)
            
            try writeMessage(envelope)
        } catch {
            print("Failed to send message: \(error)")
        }
    }
    
    private func _sendMessageWithReply<T: Codable & Sendable, R: Codable & Sendable>(
        message: T,
        identifier: String,
        replyTimeout: TimeInterval,
        completion: @Sendable @escaping (Result<R, Error>) -> Void
    ) {
        do {
            let messageID = UUID().uuidString
            let envelope = MessageEnvelope(
                id: messageID,
                identifier: identifier,
                data: try JSONEncoder().encode(message),
                timestamp: Date(),
                requiresReply: true,
                senderID: instanceID
            )
            
            // Record sent message ID to prevent self-consumption
            sentMessageIDs.insert(messageID)
            
            // Store pending reply message
            let replyHandler = ReplyHandler<R>(completion: completion)
            pendingReplies[messageID] = replyHandler
            
            // Set timeout
//            DispatchQueue.global().asyncAfter(deadline: .now() + replyTimeout) { [weak self] in
//                self?.serialQueue.async {
//                    if let _ = self?.pendingReplies.removeValue(forKey: messageID) {
//                        completion(.failure(IPCWormholeError.timeout))
//                    }
//                }
//            }
            
            try writeMessage(envelope)
        } catch {
            completion(.failure(error))
        }
    }
    
    private func writeMessage(_ envelope: MessageEnvelope) throws {
        let data = try JSONEncoder().encode(envelope)
        let fileURL = directoryURL.appendingPathComponent("\(envelope.id).json")
        try data.write(to: fileURL, options: .atomic)
    }
    
    private func handleFileSystemEvent() {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ).filter { $0.pathExtension == "json" }
            
            // Sort by modification time, process new files first
            let sortedFiles = fileURLs.sorted { url1, url2 in
                guard let date1 = try? url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                      let date2 = try? url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
                    return false
                }
                return date1 < date2
            }
            
            for fileURL in sortedFiles {
                handleMessageFile(fileURL)
            }
            
            // Clean cache to prevent memory leaks
            if processedFiles.count > maxProcessedFilesCache {
                let excess = processedFiles.count - maxProcessedFilesCache / 2
                let toRemove = Array(processedFiles.prefix(excess))
                processedFiles.subtract(toRemove)
            }
            
            // Clean sent message IDs cache
            if sentMessageIDs.count > maxSentMessageIDsCache {
                let excess = sentMessageIDs.count - maxSentMessageIDsCache / 2
                let toRemove = Array(sentMessageIDs.prefix(excess))
                sentMessageIDs.subtract(toRemove)
            }
            
        } catch {
            // Silently handle errors to avoid log spam
        }
    }
    
    private func handleMessageFile(_ fileURL: URL) {
        let fileName = fileURL.lastPathComponent
        
        // Check if this file has been processed
        guard !processedFiles.contains(fileName) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let envelope = try JSONDecoder().decode(MessageEnvelope.self, from: data)
            
            // Prevent self-consumption: check if it's a message sent by self
            if envelope.senderID == instanceID {
                // Mark as processed and delete file, but don't process business logic
                processedFiles.insert(fileName)
                return
            }
            
            // Also check if it's a sent message ID (double protection)
            if sentMessageIDs.contains(envelope.id) {
                processedFiles.insert(fileName)
                try? FileManager.default.removeItem(at: fileURL)
                return
            }
            
            // Mark as processed
            processedFiles.insert(fileName)
            
            // Delete processed file
            try? FileManager.default.removeItem(at: fileURL)
            
            if envelope.isReply {
                handleReplyMessage(envelope)
            } else {
                handleIncomingMessage(envelope)
            }
        } catch {
            // Delete invalid file
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    private func handleReplyMessage(_ envelope: MessageEnvelope) {
        guard let replyToID = envelope.replyToID,
              let handler = pendingReplies.removeValue(forKey: replyToID) else {
            return
        }
        
        if let replyHandler = handler as? AnyReplyHandler {
            replyHandler.handleReply(data: envelope.data)
        }
    }
    
    private func handleIncomingMessage(_ envelope: MessageEnvelope) {
        guard let listener = listeners[envelope.identifier] else {
            return
        }
        
        if let messageListener = listener as? AnyMessageListener {
            messageListener.handleMessage(
                data: envelope.data,
                replyHandler: { [weak self] replyData in
                    guard envelope.requiresReply else { return }
                    self?.serialQueue.async {
                        self?.sendReply(to: envelope, replyData: replyData)
                    }
                }
            )
        }
    }
    
    private func sendReply(to originalMessage: MessageEnvelope, replyData: Any?) {
        do {
            let replyID = UUID().uuidString
            let replyEnvelope = MessageEnvelope(
                id: replyID,
                identifier: originalMessage.identifier,
                data: try encodeReplyData(replyData),
                timestamp: Date(),
                requiresReply: false,
                isReply: true,
                replyToID: originalMessage.id,
                senderID: instanceID
            )
            
            // Record sent reply ID
            sentMessageIDs.insert(replyID)
            
            try writeMessage(replyEnvelope)
        } catch {
            print("Failed to send reply: \(error)")
        }
    }
    
    private func encodeReplyData(_ data: Any?) throws -> Data {
        if let data = data {
            if let codableData = data as? Codable {
                return try JSONEncoder().encode(AnyEncodable(codableData))
            } else {
                return try JSONSerialization.data(withJSONObject: data)
            }
        } else {
            return Data()
        }
    }
}

// MARK: - Supporting Types

private struct MessageEnvelope: Codable {
    let id: String
    let identifier: String
    let data: Data
    let timestamp: Date
    let requiresReply: Bool
    let isReply: Bool
    let replyToID: String?
    let senderID: String // Sender instance ID
    
    init(
        id: String,
        identifier: String,
        data: Data,
        timestamp: Date,
        requiresReply: Bool,
        isReply: Bool = false,
        replyToID: String? = nil,
        senderID: String
    ) {
        self.id = id
        self.identifier = identifier
        self.data = data
        self.timestamp = timestamp
        self.requiresReply = requiresReply
        self.isReply = isReply
        self.replyToID = replyToID
        self.senderID = senderID
    }
}

private protocol AnyReplyHandler {
    func handleReply(data: Data)
}

private struct ReplyHandler<T: Codable>: AnyReplyHandler {
    let completion: (Result<T, Error>) -> Void
    
        func handleReply(data: Data) {
            do {
                if data.isEmpty {
                    // For empty data, try to create a successful result of Optional type
                    if let optionalType = T.self as? OptionalProtocol.Type {
                        completion(.success(optionalType.none as! T))
                    } else {
                        completion(.failure(IPCWormholeError.invalidResponse))
                    }
                } else {
                    let response = try JSONDecoder().decode(T.self, from: data)
                    completion(.success(response))
                }
            } catch {
                completion(.failure(IPCWormholeError.serializationError(error)))
            }
        }
}

// Protocol for detecting Optional types
private protocol OptionalProtocol {
    static var none: Any { get }
}

extension Optional: OptionalProtocol {
    static var none: Any {
        return Optional<Wrapped>.none as Any
    }
}

private protocol AnyMessageListener {
    func handleMessage(data: Data, replyHandler: @escaping (Any?) -> Void)
}

private struct MessageListener<T: Codable>: AnyMessageListener {
    let handler: (T, @escaping (Any?) -> Void) -> Void
    
    func handleMessage(data: Data, replyHandler: @escaping (Any?) -> Void) {
        do {
            let message = try JSONDecoder().decode(T.self, from: data)
            handler(message, replyHandler)
        } catch {
            print("Message deserialization failed: \(error)")
        }
    }
}

private struct AnyEncodable: Codable {
    private let _encode: (Encoder) throws -> Void
    
    init<T: Encodable>(_ value: T) {
        _encode = value.encode
    }
    
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
    
    init(from decoder: Decoder) throws {
        fatalError("AnyEncodable does not support decoding")
    }
}

// MARK: - File Presenter

/// File monitor using NSFilePresenter to monitor directory changes in real time
private class IPCFilePresenter: NSObject, NSFilePresenter {
    let presentedItemURL: URL?
    let presentedItemOperationQueue: OperationQueue
    private let changeHandler: () -> Void
    private var isActive = true
    
    init(directoryURL: URL, changeHandler: @escaping () -> Void) {
        self.presentedItemURL = directoryURL
        self.presentedItemOperationQueue = OperationQueue()
        self.presentedItemOperationQueue.maxConcurrentOperationCount = 1
        self.presentedItemOperationQueue.name = "com.ipcwormhole.filepresenter.operations"
        self.changeHandler = changeHandler
        super.init()
    }
    
    deinit {
        isActive = false
    }
    
    // MARK: - NSFilePresenter
    
    /// Called when subitem appears
    func presentedSubitemDidAppear(at url: URL) {
        guard isActive else {
            return
        }
        
        if url.pathExtension == "json" {
            // Use async delay to avoid issues with files not yet fully written
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) { [weak self] in
                guard let self = self, self.isActive else { return }
                self.changeHandler()
            }
        }
    }
    
    /// Called when subitem changes
    func presentedSubitemDidChange(at url: URL) {
        guard isActive else { return }
        
        if url.pathExtension == "json" {
            changeHandler()
        }
    }
    
    /// Directory content changes
    func presentedItemDidChange() {
        guard isActive else { return }
        changeHandler()
    }
    
    /// Called when subitem is removed
    func presentedSubitemDidDisappear(at url: URL) {
        // No special handling needed when files are deleted, as we delete files after processing
    }
    
    /// Handle file coordinator errors
    func presentedItemDidMove(to newURL: URL) {
        // Handle directory move, but unlikely to happen for our use case
    }
    
    /// Handle error cases
    func presentedItemDidLose(_ version: NSFileVersion) {
        // File version lost, can handle recovery logic here
    }
    
    /// Handle file coordinator read errors
    func presentedItemDidGain(_ version: NSFileVersion) {
        // Got new version, may need to reprocess
        guard isActive else { return }
        changeHandler()
    }
    
    /// Handle file coordinator conflicts
    func presentedItemDidResolveConflict(_ version: NSFileVersion) {
        // Reprocess after resolving conflicts
        guard isActive else { return }
        changeHandler()
    }
}

// MARK: - IPCWormhole Extensions

public extension IPCWormhole {
    
    /// Send string message (convenience method)
    /// - Parameters:
    ///   - message: String message to send
    ///   - identifier: Message identifier
    func sendStringMessage(_ message: String, identifier: String) {
        sendMessage(message, identifier: identifier)
    }
    
    /// Send string message and wait for reply (convenience method)
    /// - Parameters:
    ///   - message: String message to send
    ///   - identifier: Message identifier
    ///   - replyTimeout: Reply timeout duration
    /// - Returns: Reply string message
    func sendStringMessageWithReply(
        message: String,
        identifier: String,
        replyTimeout: TimeInterval = 10.0
    ) async throws -> String {
        return try await sendMessageWithReply(
            message: message,
            identifier: identifier,
            replyTimeout: replyTimeout
        )
    }
    
    /// Listen for string messages (convenience method)
    /// - Parameters:
    ///   - identifier: Message identifier
    ///   - handler: Message handler
    func listenStringMessage(
        for identifier: String,
        handler: @escaping (String, @escaping (String?) -> Void) -> Void
    ) {
        listenMessage(for: identifier) { (message: String, reply: @escaping (Any?) -> Void) in
            handler(message) { replyString in
                reply(replyString)
            }
        }
    }
    
    /// Remove message listener
    /// - Parameter identifier: Message identifier
    func removeListener(for identifier: String) {
        serialQueue.async { [weak self] in
            self?.listeners.removeValue(forKey: identifier)
        }
    }
    
    /// Remove all message listeners
    func removeAllListeners() {
        serialQueue.async { [weak self] in
            self?.listeners.removeAll()
        }
    }
    
    /// Get currently listening message identifier list
    /// - Parameter completion: Completion callback, returns identifier list
    func getListeningIdentifiers(completion: @escaping ([String]) -> Void) {
        serialQueue.async { [weak self] in
            let identifiers = Array(self?.listeners.keys ?? Dictionary<String, Any>().keys)
            DispatchQueue.main.async {
                completion(identifiers)
            }
        }
    }
    
    /// Clear processed files cache (for memory management)
    func clearProcessedFilesCache() {
        serialQueue.async { [weak self] in
            self?.processedFiles.removeAll()
        }
    }
    
    /// Get statistics
    /// - Parameter completion: Completion callback, returns statistics
    func getStatistics(completion: @escaping (IPCWormholeStatistics) -> Void) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            
            let stats = IPCWormholeStatistics(
                listeningIdentifiersCount: self.listeners.count,
                pendingRepliesCount: self.pendingReplies.count,
                processedFilesCount: self.processedFiles.count,
                isMonitoring: self.filePresenter != nil
            )
            
            DispatchQueue.main.async {
                completion(stats)
            }
        }
    }
}

public extension IPCWormhole {
    
    /// Send data message (convenience method)
    /// - Parameters:
    ///   - message: Data message to send
    ///   - identifier: Message identifier
    func sendDataMessage(_ message: Data, identifier: String) {
        sendMessage(message, identifier: identifier)
    }
    
    /// Send data message and wait for reply (convenience method)
    /// - Parameters:
    ///   - message: Data message to send
    ///   - identifier: Message identifier
    ///   - replyTimeout: Reply timeout duration
    /// - Returns: Reply data message
    func sendDataMessageWithReply(
        message: Data,
        identifier: String,
        replyTimeout: TimeInterval = 10.0
    ) async throws -> Data {
        return try await sendMessageWithReply(
            message: message,
            identifier: identifier,
            replyTimeout: replyTimeout
        )
    }
    
    /// Listen for data messages (convenience method)
    /// - Parameters:
    ///   - identifier: Message identifier
    ///   - handler: Message handler
    func listenDataMessage(
        for identifier: String,
        handler: @escaping (Data, @escaping (Data?) -> Void) -> Void
    ) {
        listenMessage(for: identifier) { (message: Data, reply: @escaping (Any?) -> Void) in
            handler(message) { replyString in
                reply(replyString)
            }
        }
    }
}

// MARK: - Statistics

/// IPCWormhole statistics
public struct IPCWormholeStatistics {
    /// Current number of listening message identifiers
    public let listeningIdentifiersCount: Int
    
    /// Number of pending replies
    public let pendingRepliesCount: Int
    
    /// Number of processed file cache
    public let processedFilesCount: Int
    
    /// Whether monitoring is active
    public let isMonitoring: Bool
}
