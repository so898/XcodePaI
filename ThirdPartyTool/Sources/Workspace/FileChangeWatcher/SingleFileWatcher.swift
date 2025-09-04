import Foundation
import Logger

class SingleFileWatcher: FileWatcherProtocol {
    private var fileDescriptor: CInt = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private let fileURL: URL
    private let dispatchQueue: DispatchQueue?
    
    // Callbacks for file events
    private let onFileModified: (() -> Void)?
    private let onFileDeleted: (() -> Void)?
    private let onFileRenamed: (() -> Void)?

    init(
        fileURL: URL,
        dispatchQueue: DispatchQueue? = nil,
        onFileModified: (() -> Void)? = nil,
        onFileDeleted: (() -> Void)? = nil,
        onFileRenamed: (() -> Void)? = nil
    ) {
        self.fileURL = fileURL
        self.dispatchQueue = dispatchQueue
        self.onFileModified = onFileModified
        self.onFileDeleted = onFileDeleted
        self.onFileRenamed = onFileRenamed
    }

    func startWatching() -> Bool {
        // Open the file for event-only monitoring
        fileDescriptor = open(fileURL.path, O_EVTONLY)
        guard fileDescriptor != -1 else {
            Logger.client.info("[FileWatcher] Failed to open file \(fileURL.path).")
            return false
        }

        // Create DispatchSource to monitor the file descriptor
        dispatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: self.dispatchQueue ?? DispatchQueue.global()
        )

        dispatchSource?.setEventHandler { [weak self] in
            guard let self = self else { return }

            let flags = self.dispatchSource?.data ?? []

            if flags.contains(.write) {
                self.onFileModified?()
            }
            if flags.contains(.delete) {
                self.onFileDeleted?()
                self.stopWatching()
            }
            if flags.contains(.rename) {
                self.onFileRenamed?()
                self.stopWatching()
            }
        }

        dispatchSource?.setCancelHandler { [weak self] in
            guard let self = self else { return }
            close(self.fileDescriptor)
            self.fileDescriptor = -1
        }

        dispatchSource?.resume()
        Logger.client.info("[FileWatcher] Started watching file: \(fileURL.path)")
        return true
    }

    func stopWatching() {
        dispatchSource?.cancel()
        dispatchSource = nil
    }

    deinit {
        stopWatching()
    }
}
