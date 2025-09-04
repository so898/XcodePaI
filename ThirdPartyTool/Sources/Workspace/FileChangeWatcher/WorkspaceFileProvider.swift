import CopilotForXcodeKit
import Foundation

public protocol WorkspaceFileProvider {
    func getProjects(by workspaceURL: URL) -> [URL]
    func isXCProject(_ url: URL) -> Bool
    func isXCWorkspace(_ url: URL) -> Bool
    func fileExists(atPath: String) -> Bool
}

public class FileChangeWatcherWorkspaceFileProvider: WorkspaceFileProvider {
    public init() {}
    
    public func getProjects(by workspaceURL: URL) -> [URL] {
        guard let workspaceInfo = WorkspaceFile.getWorkspaceInfo(workspaceURL: workspaceURL)
        else { return [] }
        
        return WorkspaceFile.getProjects(workspace: workspaceInfo).compactMap { URL(string: $0.uri) }
    }
    
    public func isXCProject(_ url: URL) -> Bool {
        return WorkspaceFile.isXCProject(url)
    }
    
    public func isXCWorkspace(_ url: URL) -> Bool {
        return WorkspaceFile.isXCWorkspace(url)
    }

    public func fileExists(atPath: String) -> Bool {
        return FileManager.default.fileExists(atPath: atPath)
    }
}
