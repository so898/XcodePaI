import AppKit
import Combine
import Foundation
import Logger
import Preferences
import Status
import SuggestionBasic
import SystemUtils
import SuggestionPortal

public protocol GitHubCopilotSuggestionServiceType {
    func getCompletions(
        fileURL: URL,
        content: String,
        originalContent: String,
        cursorPosition: CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool
    ) async throws -> [CodeSuggestion]
    func notifyShown(_ completion: CodeSuggestion) async
    func notifyAccepted(_ completion: CodeSuggestion, acceptedLength: Int?) async
    func notifyRejected(_ completions: [CodeSuggestion]) async
    func notifyOpenTextDocument(fileURL: URL, content: String) async throws
    func notifyChangeTextDocument(fileURL: URL, content: String, version: Int) async throws
    func notifyCloseTextDocument(fileURL: URL) async throws
    func notifySaveTextDocument(fileURL: URL) async throws
    func cancelRequest() async
    func terminate() async
}

public extension Notification.Name {
    static let gitHubCopilotShouldRefreshEditorInformation = Notification
        .Name("com.tpp.CopilotForXcode.GitHubCopilotShouldRefreshEditorInformation")
}

public class GitHubCopilotBaseService {
    let projectRootURL: URL
    let sessionId: String

    init(projectRootURL: URL, workspaceURL: URL = URL(fileURLWithPath: "/")) throws {
        self.projectRootURL = projectRootURL
        self.sessionId = UUID().uuidString
    }
    
    

    public static func createFoldersIfNeeded() throws -> (
        applicationSupportURL: URL,
        gitHubCopilotURL: URL,
        executableURL: URL,
        supportURL: URL
    ) {
        guard let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent(
            Bundle.main
                .object(forInfoDictionaryKey: "APPLICATION_SUPPORT_FOLDER") as? String
            ?? "com.tpp.CopilotForXcode"
        ) else {
            throw CancellationError()
        }

        if !FileManager.default.fileExists(atPath: supportURL.path) {
            try? FileManager.default
                .createDirectory(at: supportURL, withIntermediateDirectories: false)
        }
        let gitHubCopilotFolderURL = supportURL.appendingPathComponent("GitHub Copilot")
        if !FileManager.default.fileExists(atPath: gitHubCopilotFolderURL.path) {
            try? FileManager.default
                .createDirectory(at: gitHubCopilotFolderURL, withIntermediateDirectories: false)
        }
        let supportFolderURL = gitHubCopilotFolderURL.appendingPathComponent("support")
        if !FileManager.default.fileExists(atPath: supportFolderURL.path) {
            try? FileManager.default
                .createDirectory(at: supportFolderURL, withIntermediateDirectories: false)
        }
        let executableFolderURL = gitHubCopilotFolderURL.appendingPathComponent("executable")
        if !FileManager.default.fileExists(atPath: executableFolderURL.path) {
            try? FileManager.default
                .createDirectory(at: executableFolderURL, withIntermediateDirectories: false)
        }

        return (supportURL, gitHubCopilotFolderURL, executableFolderURL, supportFolderURL)
    }
    
    public func getSessionId() -> String {
        return sessionId
    }
}

@globalActor public enum GitHubCopilotSuggestionActor {
    public actor TheActor {}
    public static let shared = TheActor()
}

public final class GitHubCopilotService:
    GitHubCopilotBaseService,
    GitHubCopilotSuggestionServiceType
{
    private var ongoingTasks = Set<Task<[CodeSuggestion], Error>>()
    private var cancellables = Set<AnyCancellable>()
    private static var services: [GitHubCopilotService] = [] // cache all alive copilot service instances
    private var isMCPInitialized = false
    private var unrestoredMcpServers: [String] = []
    private var mcpRuntimeLogFileName: String = ""

    override public init(projectRootURL: URL = URL(fileURLWithPath: "/"), workspaceURL: URL = URL(fileURLWithPath: "/")) throws {
        do {
            try super.init(projectRootURL: projectRootURL, workspaceURL: workspaceURL)

            self.handleSendWorkspaceDidChangeNotifications()

            GitHubCopilotService.services.append(self)

        } catch {
            Logger.gitHubCopilot.error(error)
            throw error
        }
        
    }

    deinit {
        GitHubCopilotService.services.removeAll { $0 === self }
    }

    @GitHubCopilotSuggestionActor
    public func getCompletions(
        fileURL: URL,
        content: String,
        originalContent: String,
        cursorPosition: SuggestionBasic.CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool
    ) async throws -> [CodeSuggestion] {
        ongoingTasks.forEach { $0.cancel() }
        ongoingTasks.removeAll()

        func sendRequest(maxTry: Int = 5) async throws -> [CodeSuggestion] {
            do {
                let completions = try await SuggestionPortal.shared.requestSuggestion(
                    fileURL: fileURL,
                    originalContent: originalContent,
                    cursorPosition: cursorPosition)
                try Task.checkCancellation()
                return completions
            } catch {
                throw error
            }
        }

        func recoverContent() async {
            try? await notifyChangeTextDocument(
                fileURL: fileURL,
                content: originalContent,
                version: 0
            )
        }

        // since when the language server is no longer using the passed in content to generate
        // suggestions, we will need to update the content to the file before we do any request.
        //
        // And sometimes the language server's content was not up to date and may generate
        // weird result when the cursor position exceeds the line.
        let task = Task { @GitHubCopilotSuggestionActor in
            try? await notifyChangeTextDocument(
                fileURL: fileURL,
                content: content,
                version: 1
            )

            do {
                try Task.checkCancellation()
                return try await sendRequest()
            } catch let error as CancellationError {
                if ongoingTasks.isEmpty {
                    await recoverContent()
                }
                throw error
            } catch {
                await recoverContent()
                throw error
            }
        }

        ongoingTasks.insert(task)

        return try await task.value
    }

    @GitHubCopilotSuggestionActor
    public func cancelRequest() async {
        ongoingTasks.forEach { $0.cancel() }
        ongoingTasks.removeAll()
    }

    @GitHubCopilotSuggestionActor
    public func cancelProgress(token: String) async {
        
    }

    @GitHubCopilotSuggestionActor
    public func notifyShown(_ completion: CodeSuggestion) async {
        

    }

    @GitHubCopilotSuggestionActor
    public func notifyAccepted(_ completion: CodeSuggestion, acceptedLength: Int? = nil) async {
        
    }

    @GitHubCopilotSuggestionActor
    public func notifyRejected(_ completions: [CodeSuggestion]) async {
        
    }

    @GitHubCopilotSuggestionActor
    public func notifyOpenTextDocument(
        fileURL: URL,
        content: String
    ) async throws {
        let languageId = languageIdentifierFromFileURL(fileURL)
        let uri = "file://\(fileURL.path)"
        //        Logger.service.debug("Open \(uri), \(content.count)")
//        try await server.sendNotification(
//            .textDocumentDidOpen(
//                DidOpenTextDocumentParams(
//                    textDocument: .init(
//                        uri: uri,
//                        languageId: languageId.rawValue,
//                        version: 0,
//                        text: content
//                    )
//                )
//            )
//        )
    }

    @GitHubCopilotSuggestionActor
    public func notifyChangeTextDocument(
        fileURL: URL,
        content: String,
        version: Int
    ) async throws {
        let uri = "file://\(fileURL.path)"
        //        Logger.service.debug("Change \(uri), \(content.count)")
//        try await server.sendNotification(
//            .textDocumentDidChange(
//                DidChangeTextDocumentParams(
//                    uri: uri,
//                    version: version,
//                    contentChange: .init(
//                        range: nil,
//                        rangeLength: nil,
//                        text: content
//                    )
//                )
//            )
//        )
    }

    @GitHubCopilotSuggestionActor
    public func notifySaveTextDocument(fileURL: URL) async throws {
        let uri = "file://\(fileURL.path)"
        //        Logger.service.debug("Save \(uri)")
//        try await server.sendNotification(.textDocumentDidSave(.init(uri: uri)))
    }

    @GitHubCopilotSuggestionActor
    public func notifyCloseTextDocument(fileURL: URL) async throws {
        let uri = "file://\(fileURL.path)"
        //        Logger.service.debug("Close \(uri)")
//        try await server.sendNotification(.textDocumentDidClose(.init(uri: uri)))
    }

    @GitHubCopilotSuggestionActor
    public func terminate() async {
        // automatically handled
    }
    
    public func handleSendWorkspaceDidChangeNotifications() {
        Task {
            if projectRootURL.path != "/" {
//                try? await self.server.sendNotification(
//                    .workspaceDidChangeWorkspaceFolders(
//                        .init(event: .init(added: [.init(uri: projectRootURL.absoluteString, name: projectRootURL.lastPathComponent)], removed: []))
//                    )
//                )
            }
            NotificationCenter.default.publisher(for: .gitHubCopilotShouldRefreshEditorInformation).map { _ in "editorInfo" }
        }
    }
}
