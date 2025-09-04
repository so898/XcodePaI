import Foundation
import System
import Logger
import CoreServices
import XcodeInspector

public class FileChangeWatcherService {
    internal var watcher: DirectoryWatcherProtocol?
    
    private(set) public var workspaceURL: URL
    private(set) public var publisher: PublisherType
    private(set) public var publishInterval: TimeInterval
    private(set) public var directoryChangePublisher: PublisherType?
    
    // Dependencies injected for testing
    internal let workspaceFileProvider: WorkspaceFileProvider
    internal let watcherFactory: FileWatcherFactory
    
    // Watching workspace metadata file
    private var workspaceConfigFileWatcher: FileWatcherProtocol?
    private var isMonitoringWorkspaceConfigFile = false
    private let monitoringQueue = DispatchQueue(label: "com.tpp.copilot.workspaceMonitor", qos: .utility)
    private let configFileEventQueue = DispatchQueue(label: "com.tpp.copilot.workspaceEventMonitor", qos: .utility)

    public init(
        _ workspaceURL: URL,
        publisher: @escaping PublisherType,
        publishInterval: TimeInterval = 3.0,
        workspaceFileProvider: WorkspaceFileProvider = FileChangeWatcherWorkspaceFileProvider(),
        watcherFactory: FileWatcherFactory? = nil,
        directoryChangePublisher: PublisherType?
    ) {
        self.workspaceURL = workspaceURL
        self.publisher = publisher
        self.publishInterval = publishInterval
        self.workspaceFileProvider = workspaceFileProvider
        self.watcherFactory = watcherFactory ?? DefaultFileWatcherFactory()
        self.directoryChangePublisher = directoryChangePublisher
    }
    
    deinit {
        stopWorkspaceConfigFileMonitoring()
        self.watcher = nil
    }

    public func startWatching() {
        guard workspaceURL.path != "/" else { return }
        
        guard watcher == nil else { return }

        let projects = workspaceFileProvider.getProjects(by: workspaceURL)
        guard projects.count > 0 else { return }
        
        watcher = watcherFactory.createDirectoryWatcher(
            watchedPaths: projects, 
            changePublisher: publisher, 
            publishInterval: publishInterval,
            directoryChangePublisher: directoryChangePublisher
        )
        Logger.client.info("Started watching for file changes in \(projects)")
        
        startWatchingProject()
    }
    
    internal func startWatchingProject() {
        if self.workspaceFileProvider.isXCWorkspace(self.workspaceURL) {
            guard !isMonitoringWorkspaceConfigFile else { return }
            isMonitoringWorkspaceConfigFile = true
            recreateConfigFileMonitor()
        }
    }

    private func recreateConfigFileMonitor() {
        let workspaceDataFile = workspaceURL.appendingPathComponent("contents.xcworkspacedata")

        // Clean up existing monitor first
        cleanupCurrentMonitor()

        guard self.workspaceFileProvider.fileExists(atPath: workspaceDataFile.path) else {
            Logger.client.info("[FileWatcher] contents.xcworkspacedata file not found at \(workspaceDataFile.path).")
            return
        }

        // Create SingleFileWatcher for the workspace file
        workspaceConfigFileWatcher = self.watcherFactory.createFileWatcher(
            fileURL: workspaceDataFile,
            dispatchQueue: configFileEventQueue,
            onFileModified: { [weak self] in
                self?.handleWorkspaceConfigFileChange()
                self?.scheduleMonitorRecreation(delay: 1.0)
            },
            onFileDeleted: { [weak self] in
                self?.handleWorkspaceConfigFileChange()
                self?.scheduleMonitorRecreation(delay: 1.0)
            },
            onFileRenamed: nil
        )

        let _ = workspaceConfigFileWatcher?.startWatching()
    }

    private func handleWorkspaceConfigFileChange() {
        guard let watcher = self.watcher else {
            return
        }

        let workspaceDataFile = workspaceURL.appendingPathComponent("contents.xcworkspacedata")
        // Check if file still exists
        let fileExists = self.workspaceFileProvider.fileExists(atPath: workspaceDataFile.path)
        if fileExists {
            // File was modified, check for project changes
            let watchingProjects = Set(watcher.paths())
            let projects = Set(self.workspaceFileProvider.getProjects(by: self.workspaceURL))

            /// find added projects
            let addedProjects = projects.subtracting(watchingProjects)
            if !addedProjects.isEmpty {
                self.onProjectAdded(Array(addedProjects))
            }

            /// find removed projects
            let removedProjects = watchingProjects.subtracting(projects)
            if !removedProjects.isEmpty {
                self.onProjectRemoved(Array(removedProjects))
            }
        } else {
            Logger.client.info("[FileWatcher] contents.xcworkspacedata file was deleted")
        }
    }

    private func scheduleMonitorRecreation(delay: TimeInterval) {
        monitoringQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.isMonitoringWorkspaceConfigFile else { return }
            self.recreateConfigFileMonitor()
        }
    }
    
    private func cleanupCurrentMonitor() {
        workspaceConfigFileWatcher?.stopWatching()
        workspaceConfigFileWatcher = nil
    }
    
    private func stopWorkspaceConfigFileMonitoring() {
        isMonitoringWorkspaceConfigFile = false
        cleanupCurrentMonitor()
    }

    internal func onProjectAdded(_ projectURLs: [URL]) {
        guard let watcher = watcher, projectURLs.count > 0 else { return }
        
        watcher.addPaths(projectURLs)

        Logger.client.info("Started watching for file changes in \(projectURLs)")
        
        /// sync all the files as created in the project when added
//        for projectURL in projectURLs {
//            let files = workspaceFileProvider.getFilesInActiveWorkspace(
//                workspaceURL: projectURL,
//                workspaceRootURL: projectURL
//            )
//            publisher(files.map { .init(uri: $0.url.absoluteString, type: .created) })
//        }
    }
    
    internal func onProjectRemoved(_ projectURLs: [URL]) {
        guard let watcher = watcher, projectURLs.count > 0 else { return }
        
        watcher.removePaths(projectURLs)
        
        Logger.client.info("Stopped watching for file changes in \(projectURLs)")
        
        /// sync all the files as deleted in the project when removed
//        for projectURL in projectURLs {
//            let files = workspaceFileProvider.getFilesInActiveWorkspace(workspaceURL: projectURL, workspaceRootURL: projectURL)
//            publisher(files.map { .init(uri: $0.url.absoluteString, type: .deleted) })
//        }
    }
}

@globalActor
public enum PoolActor: GlobalActor {
    public actor Actor {}
    public static let shared = Actor()
}

public class FileChangeWatcherServicePool {
    
    public static let shared = FileChangeWatcherServicePool()
    private var servicePool: [URL: FileChangeWatcherService] = [:]
    
    private init() {}
    
    @PoolActor
    public func watch(
        for workspaceURL: URL, 
        publisher: @escaping PublisherType,
        directoryChangePublisher: PublisherType? = nil
    ) {
        guard workspaceURL.path != "/" else { return }
        
        var validWorkspaceURL: URL? = nil
        if WorkspaceFile.isXCWorkspace(workspaceURL) {
            validWorkspaceURL = workspaceURL
        } else if WorkspaceFile.isXCProject(workspaceURL) {
            validWorkspaceURL = WorkspaceFile.getWorkspaceByProject(workspaceURL)
        }
        
        guard let validWorkspaceURL else { return }
        
        guard servicePool[workspaceURL] == nil else { return }
        
        let watcherService = FileChangeWatcherService(
            validWorkspaceURL, 
            publisher: publisher,
            directoryChangePublisher: directoryChangePublisher
        )
        watcherService.startWatching()
        
        servicePool[workspaceURL] = watcherService
    }
}
