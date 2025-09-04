import Foundation
import Logger
import Workspace

public final class GitHubCopilotWorkspacePlugin: WorkspacePlugin {
    public var gitHubCopilotService: GitHubCopilotService?

    public override init(workspace: Workspace) {
        super.init(workspace: workspace)
        do {
            gitHubCopilotService = try createGitHubCopilotService()
        } catch {
            Logger.gitHubCopilot.error("Failed to create GitHub Copilot service: \(error)")
        }
    }

    deinit {
        if let gitHubCopilotService {
            Task { await gitHubCopilotService.terminate() }
        }
    }

    func createGitHubCopilotService() throws -> GitHubCopilotService {
        let newService = try GitHubCopilotService(projectRootURL: projectRootURL, workspaceURL: workspaceURL)
        Task {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            finishLaunchingService()
        }
        return newService
    }

    func finishLaunchingService() {
        guard let workspace, let gitHubCopilotService else { return }
        Task {
            for (_, filespace) in workspace.filespaces {
                let documentURL = filespace.fileURL
                guard let content = try? String(contentsOf: documentURL) else { continue }
                try? await gitHubCopilotService.notifyOpenTextDocument(
                    fileURL: documentURL,
                    content: content
                )
            }
        }
    }

    func terminate() {
        gitHubCopilotService = nil
    }
}

