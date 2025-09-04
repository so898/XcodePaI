import Foundation

public class DefaultFileWatcherFactory: FileWatcherFactory {
    public init() {}

    public func createFileWatcher(fileURL: URL, dispatchQueue: DispatchQueue?,
                              onFileModified: (() -> Void)? = nil, onFileDeleted: (() -> Void)? = nil, onFileRenamed: (() -> Void)? = nil) -> FileWatcherProtocol {
        return SingleFileWatcher(fileURL: fileURL,
                                 dispatchQueue: dispatchQueue,
                                 onFileModified: onFileModified,
                                 onFileDeleted: onFileDeleted,
                                 onFileRenamed: onFileRenamed
        )
    }

    public func createDirectoryWatcher(
        watchedPaths: [URL], 
        changePublisher: @escaping PublisherType,
        publishInterval: TimeInterval,
        directoryChangePublisher: PublisherType? = nil
    ) -> DirectoryWatcherProtocol {
        return BatchingFileChangeWatcher(
            watchedPaths: watchedPaths,
            changePublisher: changePublisher,
            publishInterval: publishInterval,
            fsEventProvider: FileChangeWatcherFSEventProvider(),
            directoryChangePublisher: directoryChangePublisher
        )
    }
}
