import Foundation
import System
import Logger

public final class BatchingFileChangeWatcher: DirectoryWatcherProtocol {
    private var watchedPaths: [URL]
    private let changePublisher: PublisherType
    private let directoryChangePublisher: PublisherType?
    private let publishInterval: TimeInterval
    
    private var pendingEvents: [FileEvent] = []
    private var pendingDirectoryEvents: [FileEvent] = []
    private var timer: Timer?
    private let eventQueue: DispatchQueue
    private let directoryEventQueue: DispatchQueue
    private let fsEventQueue: DispatchQueue
    private var eventStream: FSEventStreamRef?
    private(set) public var isWatching = false
    
    // Dependencies injected for testing
    private let fsEventProvider: FSEventProvider

    /// TODO: set a proper value for stdio
    public static let maxEventPublishSize = 100
    
    init(
        watchedPaths: [URL],
        changePublisher: @escaping PublisherType,
        publishInterval: TimeInterval = 3.0,
        fsEventProvider: FSEventProvider = FileChangeWatcherFSEventProvider(),
        directoryChangePublisher: PublisherType? = nil
    ) {
        self.watchedPaths = watchedPaths
        self.changePublisher = changePublisher
        self.publishInterval = publishInterval
        self.fsEventProvider = fsEventProvider
        self.eventQueue = DispatchQueue(label: "com.tpp.copilot.filechangewatcher.file")
        self.directoryEventQueue = DispatchQueue(label: "com.tpp.copilot.filechangewatcher.directory")
        self.fsEventQueue = DispatchQueue(label: "com.tpp.copilot.filechangewatcherfseventstream", qos: .utility)
        self.directoryChangePublisher = directoryChangePublisher
        
        self.start()
    }
    
    private func updateWatchedPaths(_ paths: [URL]) {
        guard isWatching, paths != watchedPaths else { return }
        stopWatching()
        watchedPaths = paths
        _ = startWatching()
    }
    
    public func addPaths(_ paths: [URL]) {
        let newPaths = paths.filter { !watchedPaths.contains($0) }
        if !newPaths.isEmpty {
            let updatedPaths = watchedPaths + newPaths
            updateWatchedPaths(updatedPaths)
        }
    }
    
    public func removePaths(_ paths: [URL]) {
        let updatedPaths = watchedPaths.filter { !paths.contains($0) }
        if updatedPaths.count != watchedPaths.count {
            updateWatchedPaths(updatedPaths)
        }
    }

    public func paths() -> [URL] {
        return watchedPaths
    }

    internal func start() {
        guard !isWatching else { return }
        
        guard self.startWatching() else {
            Logger.client.info("Failed to start watching for: \(watchedPaths)")
            return
        }
        self.startPublishTimer()
        isWatching = true
    }
    
    deinit {
        stopWatching()
        self.timer?.invalidate()
    }
    
    internal func startPublishTimer() {
        guard self.timer == nil else { return }
        
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: self.publishInterval, repeats: true) { [weak self] _ in
                self?.publishChanges()
                self?.publishDirectoryChanges()
            }
        }
    }
    
    internal func addEvent(file: URL, type: FileChangeType) {
        eventQueue.async {
            self.pendingEvents.append(FileEvent(uri: file.absoluteString, type: type))
        }
    }
    
    internal func addDirectoryEvent(directory: URL, type: FileChangeType) {
        guard self.directoryChangePublisher != nil else {
            return
        }
        directoryEventQueue.async {
            self.pendingDirectoryEvents.append(FileEvent(uri: directory.absoluteString, type: type))
        }
    }
    
    /// When `.deleted`, the `isDirectory` will be `nil`
    public func onFsEvent(url: URL, type: FileChangeType, isDirectory: Bool?) {
        // Could be file or directory
        if type == .deleted, isDirectory == nil {
            addEvent(file: url, type: type)
            addDirectoryEvent(directory: url, type: type)
            return
        }
        
        guard let isDirectory else { return }
        
        if isDirectory {
            addDirectoryEvent(directory: url, type: type)
        } else {
            addEvent(file: url, type: type)
        }
    }
    
    private func publishChanges() {
        eventQueue.async {
            guard !self.pendingEvents.isEmpty else { return }
            
            let compressedEventArray = self.compressEvents(self.pendingEvents)
            
            let changes = Array(compressedEventArray.prefix(BatchingFileChangeWatcher.maxEventPublishSize))
            if compressedEventArray.count > BatchingFileChangeWatcher.maxEventPublishSize {
                self.pendingEvents = Array(compressedEventArray[BatchingFileChangeWatcher.maxEventPublishSize..<compressedEventArray.count])
            } else {
                self.pendingEvents.removeAll()
            }
            
            if !changes.isEmpty {
                DispatchQueue.main.async {
                    self.changePublisher(changes)
                }
            }
        }
    }
    
    private func publishDirectoryChanges() {
        guard let directoryChangePublisher = self.directoryChangePublisher else {
            return
        }
        directoryEventQueue.async {
            guard !self.pendingDirectoryEvents.isEmpty else { 
                return 
            }
            
            let compressedEventArray = self.compressEvents(self.pendingDirectoryEvents)
            let changes = Array(compressedEventArray.prefix(Self.maxEventPublishSize))
            if compressedEventArray.count > Self.maxEventPublishSize {
                self.pendingDirectoryEvents = Array(
                    compressedEventArray[Self.maxEventPublishSize..<compressedEventArray.count]
                )
            } else {
                self.pendingDirectoryEvents.removeAll()
            }
            
            if !changes.isEmpty {
                DispatchQueue.main.async {
                    directoryChangePublisher(changes)
                }
            }
        }
    }
    
    private func compressEvents(_ events: [FileEvent]) -> [FileEvent] {
        var compressedEvent: [String: FileEvent] = [:]
        for event in events {
            let existingEvent = compressedEvent[event.uri]
            
            guard existingEvent != nil else {
                compressedEvent[event.uri] = event
                continue
            }
            
            if event.type == .deleted { /// file deleted. Cover created and changed event
                compressedEvent[event.uri] = event
            } else if event.type == .created { /// file created. Cover deleted and changed event
                compressedEvent[event.uri] = event
            } else if event.type == .changed {
                if existingEvent?.type != .created { /// file changed. Won't cover created event
                    compressedEvent[event.uri] = event
                }
            }
        }
        
        let compressedEventArray: [FileEvent] = Array(compressedEvent.values)
        
        return compressedEventArray
    }
    
    /// Starts watching  for file changes in the project
    public func startWatching() -> Bool {
        isWatching = true
        var isEventStreamStarted = false
        
        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()
        
        let paths = watchedPaths.map { $0.path } as CFArray
        let flags = UInt32(
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer |
            kFSEventStreamCreateFlagWatchRoot
        )
        
        eventStream = fsEventProvider.createEventStream(
            paths: paths,
            latency: 1, // 1 second latency,
            flags: flags,
            callback: { _, clientCallbackInfo, numEvents, eventPaths, eventFlags, _ in
                guard let clientCallbackInfo = clientCallbackInfo else { return }
                let watcher = Unmanaged<BatchingFileChangeWatcher>.fromOpaque(clientCallbackInfo).takeUnretainedValue()
                watcher.processEvent(numEvents: numEvents, eventPaths: eventPaths, eventFlags: eventFlags)
            },
            context: &context
        )
        
        if let eventStream = eventStream {
            fsEventProvider.setDispatchQueue(eventStream, queue: fsEventQueue)
            fsEventProvider.startStream(eventStream)
            isEventStreamStarted = true
        }
        
        return isEventStreamStarted
    }
    
    /// Stops watching for file changes
    public func stopWatching() {
        guard isWatching, let eventStream = eventStream else { return }
        
        fsEventProvider.stopStream(eventStream)
        fsEventProvider.invalidateStream(eventStream)
        fsEventProvider.releaseStream(eventStream)
        self.eventStream = nil
        
        isWatching = false
        
        Logger.client.info("Stoped watching for file changes in \(watchedPaths)")
    }
    
    public func processEvent(numEvents: CFIndex, eventPaths: UnsafeRawPointer, eventFlags: UnsafePointer<UInt32>) {
        let pathsPtr = eventPaths.bindMemory(to: UnsafeMutableRawPointer.self, capacity: numEvents)
        
        for i in 0..<numEvents {
            let pathPtr = pathsPtr[Int(i)]
            let path = String(cString: pathPtr.assumingMemoryBound(to: CChar.self))
            let flags = eventFlags[Int(i)]
            
            let url = URL(fileURLWithPath: path)
            
            // Keep this duplicated checking. Will block in advance for corresponding cases 
            guard !WorkspaceFile.shouldSkipURL(url) else {
                continue
            }
            
            let fileExists = FileManager.default.fileExists(atPath: path)
            var isDirectory: Bool?
            if fileExists {
                guard let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey]),
                      (resourceValues.isDirectory == true || resourceValues.isRegularFile == true)
                else {
                    continue
                }
                isDirectory = resourceValues.isDirectory == true
                if isDirectory == false, let isValid = try? WorkspaceFile.isValidFile(url), !isValid {
                    continue
                } else if isDirectory == true, !WorkspaceDirectory.isValidDirectory(url) {
                    continue
                }
            }
            
            /// FileSystem events can have multiple flags set simultaneously,
            
            if flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0 {
                if fileExists { 
                    onFsEvent(url: url, type: .created, isDirectory: isDirectory) 
                }
            }
            
            if flags & UInt32(kFSEventStreamEventFlagItemRemoved) != 0 {
                onFsEvent(url: url, type: .deleted, isDirectory: isDirectory)
            }
            
            /// The fiesystem report "Renamed" event when file content changed.
            if flags & UInt32(kFSEventStreamEventFlagItemRenamed) != 0 {
                if fileExists { 
                    onFsEvent(url: url, type: .changed, isDirectory: isDirectory)
                }
                else { 
                    onFsEvent(url: url, type: .deleted, isDirectory: isDirectory)
                }
            }
            
            if flags & UInt32(kFSEventStreamEventFlagItemModified) != 0 {
                if fileExists { 
                    onFsEvent(url: url, type: .changed, isDirectory: isDirectory)
                }
                else { 
                    onFsEvent(url: url, type: .deleted, isDirectory: isDirectory)
                }
            }
        }
    }
}
