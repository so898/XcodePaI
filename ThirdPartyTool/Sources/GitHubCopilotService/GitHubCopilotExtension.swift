import BuiltinExtension
import CopilotForXcodeKit
import Foundation
import Logger
import Preferences
import Workspace

public final class GitHubCopilotExtension: BuiltinExtension {
    public var suggestionServiceId: Preferences.BuiltInSuggestionFeatureProvider { .gitHubCopilot }

    public let suggestionService: GitHubCopilotSuggestionService?

    private var extensionUsage = ExtensionUsage(
        isSuggestionServiceInUse: false,
        isChatServiceInUse: false
    )
    private var isLanguageServerInUse: Bool {
        extensionUsage.isSuggestionServiceInUse || extensionUsage.isChatServiceInUse
    }

    let workspacePool: WorkspacePool

    let serviceLocator: ServiceLocator

    public init(workspacePool: WorkspacePool) {
        self.workspacePool = workspacePool
        serviceLocator = .init(workspacePool: workspacePool)
        let suggestionService = GitHubCopilotSuggestionService.init(serviceLocator: serviceLocator)
        self.suggestionService = suggestionService
    }

    public func workspaceDidOpen(_: WorkspaceInfo) {}

    public func workspaceDidClose(_: WorkspaceInfo) {}

    public func workspace(_ workspace: WorkspaceInfo, didOpenDocumentAt documentURL: URL) {
        guard isLanguageServerInUse else { return }
        // check if file size is larger than 15MB, if so, return immediately
        if let attrs = try? FileManager.default
            .attributesOfItem(atPath: documentURL.path),
            let fileSize = attrs[FileAttributeKey.size] as? UInt64,
            fileSize > 15 * 1024 * 1024
        { return }

        Task {
            let content: String
            do {
                content = try String(contentsOf: documentURL, encoding: .utf8)
            } catch {
                Logger.extension.info("Failed to read \(documentURL.lastPathComponent): \(error)")
                return
            }
            
            do {
                guard let service = await serviceLocator.getService(from: workspace) else { return }
                try await service.notifyOpenTextDocument(fileURL: documentURL, content: content)
            } catch {
                Logger.gitHubCopilot.info(error.localizedDescription)
            }
        }
    }

    public func workspace(_ workspace: WorkspaceInfo, didSaveDocumentAt documentURL: URL) {
        guard isLanguageServerInUse else { return }
        Task {
            do {
                guard let service = await serviceLocator.getService(from: workspace) else { return }
                try await service.notifySaveTextDocument(fileURL: documentURL)
            } catch {
                Logger.gitHubCopilot.info(error.localizedDescription)
            }
        }
    }

    public func workspace(_ workspace: WorkspaceInfo, didCloseDocumentAt documentURL: URL) {
        guard isLanguageServerInUse else { return }
        Task {
            do {
                guard let service = await serviceLocator.getService(from: workspace) else { return }
                try await service.notifyCloseTextDocument(fileURL: documentURL)
            } catch {
                Logger.gitHubCopilot.info(error.localizedDescription)
            }
        }
    }

    public func workspace(
        _ workspace: WorkspaceInfo,
        didUpdateDocumentAt documentURL: URL,
        content: String?
    ) {
        guard isLanguageServerInUse else { return }
        // check if file size is larger than 15MB, if so, return immediately
        if let attrs = try? FileManager.default
            .attributesOfItem(atPath: documentURL.path),
            let fileSize = attrs[FileAttributeKey.size] as? UInt64,
            fileSize > 15 * 1024 * 1024
        { return }

        Task {
            guard let content else { return }
            guard let service = await serviceLocator.getService(from: workspace) else { return }
            do {
                try await service.notifyChangeTextDocument(
                    fileURL: documentURL,
                    content: content,
                    version: 0
                )
            } catch {
                Logger.gitHubCopilot.info(error.localizedDescription)
            }
        }
    }

    public func extensionUsageDidChange(_ usage: ExtensionUsage) {
        extensionUsage = usage
        if !usage.isChatServiceInUse && !usage.isSuggestionServiceInUse {
            terminate()
        }
    }

    public func terminate() {
        for workspace in workspacePool.workspaces.values {
            guard let plugin = workspace.plugin(for: GitHubCopilotWorkspacePlugin.self)
            else { continue }
            plugin.terminate()
        }
    }
}

protocol ServiceLocatorType {
    func getService(from workspace: WorkspaceInfo) async -> GitHubCopilotService?
}

final class ServiceLocator: ServiceLocatorType {
    let workspacePool: WorkspacePool

    init(workspacePool: WorkspacePool) {
        self.workspacePool = workspacePool
    }

    func getService(from workspace: WorkspaceInfo) async -> GitHubCopilotService? {
        guard let workspace = workspacePool.workspaces[workspace.workspaceURL],
              let plugin = workspace.plugin(for: GitHubCopilotWorkspacePlugin.self)
        else {
            return nil
        }
        return plugin.gitHubCopilotService
    }
}
