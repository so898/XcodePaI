import Foundation

public typealias DocumentUri = String

public enum FileChangeType: Int, Codable, Hashable, Sendable {
    case created = 1
    case changed = 2
    case deleted = 3
}

public struct FileEvent: Codable, Hashable, Sendable {
    public var uri: DocumentUri
    public var type: FileChangeType

    public init(uri: DocumentUri, type: FileChangeType) {
        self.uri = uri
        self.type = type
    }
}

public protocol FileWatcherProtocol {
    func startWatching() -> Bool
    func stopWatching()
}

public typealias PublisherType = (([FileEvent]) -> Void)

public protocol DirectoryWatcherProtocol: FileWatcherProtocol {
    func addPaths(_ paths: [URL])
    func removePaths(_ paths: [URL])
    func paths() -> [URL]
}

public protocol FileWatcherFactory {
    func createFileWatcher(
        fileURL: URL,
        dispatchQueue: DispatchQueue?,
        onFileModified: (() -> Void)?,
        onFileDeleted: (() -> Void)?,
        onFileRenamed: (() -> Void)?
    ) -> FileWatcherProtocol

    func createDirectoryWatcher(
        watchedPaths: [URL],
        changePublisher: @escaping PublisherType,
        publishInterval: TimeInterval,
        directoryChangePublisher: PublisherType?
    ) -> DirectoryWatcherProtocol
}
