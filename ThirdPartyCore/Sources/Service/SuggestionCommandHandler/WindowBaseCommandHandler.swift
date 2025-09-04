import AppKit
import Foundation
import GitHubCopilotService
import Logger
import SuggestionInjector
import SuggestionBasic
import SuggestionWidget
import UserNotifications
import Workspace
import WorkspaceSuggestionService
import XcodeInspector

struct WindowBaseCommandHandler: SuggestionCommandHandler {
    nonisolated init() {}

    let presenter = PresentInWindowSuggestionPresenter()

    func presentSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            do {
                try await _presentSuggestions(editor: editor)
            } catch {
                presenter.presentError(error)
                Logger.service.error(error)
            }
        }
        return nil
    }

    @WorkspaceActor
    private func _presentSuggestions(editor: EditorContent) async throws {
        presenter.markAsProcessing(true)
        defer {
            presenter.markAsProcessing(false)
        }
        guard let fileURL = await XcodeInspector.shared.safe.realtimeActiveDocumentURL
        else { return }
        let (workspace, filespace) = try await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)

        try Task.checkCancellation()

        try await workspace.generateSuggestions(
            forFileAt: fileURL,
            editor: editor
        )

        try Task.checkCancellation()

        if filespace.presentingSuggestion != nil {
            presenter.presentSuggestion(fileURL: fileURL)
            workspace.notifySuggestionShown(fileFileAt: fileURL)
        } else {
            presenter.discardSuggestion(fileURL: fileURL)
        }
    }

    func presentNextSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            do {
                try await _presentNextSuggestion(editor: editor)
            } catch {
                presenter.presentError(error)
            }
        }
        return nil
    }

    @WorkspaceActor
    private func _presentNextSuggestion(editor: EditorContent) async throws {
        guard let fileURL = await XcodeInspector.shared.safe.realtimeActiveDocumentURL
        else { return }
        let (workspace, filespace) = try await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
        workspace.selectNextSuggestion(forFileAt: fileURL)

        if filespace.presentingSuggestion != nil {
            presenter.presentSuggestion(fileURL: fileURL)
            workspace.notifySuggestionShown(fileFileAt: fileURL)
        } else {
            presenter.discardSuggestion(fileURL: fileURL)
        }
    }

    func presentPreviousSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            do {
                try await _presentPreviousSuggestion(editor: editor)
            } catch {
                presenter.presentError(error)
            }
        }
        return nil
    }

    @WorkspaceActor
    private func _presentPreviousSuggestion(editor: EditorContent) async throws {
        guard let fileURL = await XcodeInspector.shared.safe.realtimeActiveDocumentURL
        else { return }
        let (workspace, filespace) = try await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
        workspace.selectPreviousSuggestion(forFileAt: fileURL)

        if filespace.presentingSuggestion != nil {
            presenter.presentSuggestion(fileURL: fileURL)
            workspace.notifySuggestionShown(fileFileAt: fileURL)
        } else {
            presenter.discardSuggestion(fileURL: fileURL)
        }
    }

    func rejectSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            do {
                try await _rejectSuggestion(editor: editor)
            } catch {
                presenter.presentError(error)
            }
        }
        return nil
    }

    @WorkspaceActor
    private func _rejectSuggestion(editor: EditorContent) async throws {
        guard let fileURL = await XcodeInspector.shared.safe.realtimeActiveDocumentURL
        else { return }

        let (workspace, _) = try await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
        workspace.rejectSuggestion(forFileAt: fileURL, editor: editor)
        presenter.discardSuggestion(fileURL: fileURL)
    }

    @WorkspaceActor
    func acceptSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        guard let fileURL = await XcodeInspector.shared.safe.realtimeActiveDocumentURL
        else { return nil }
        let (workspace, _) = try await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
        
        let injector = SuggestionInjector()
        var lines = editor.lines
        var cursorPosition = editor.cursorPosition
        var extraInfo = SuggestionInjector.ExtraInfo()
        
        if let acceptedSuggestion = workspace.acceptSuggestion(
            forFileAt: fileURL,
            editor: editor,
            suggestionLineLimit: ExpandableSuggestionService.shared.isSuggestionExpanded ? nil : 1
        ) {
            injector.acceptSuggestion(
                intoContentWithoutSuggestion: &lines,
                cursorPosition: &cursorPosition,
                completion: acceptedSuggestion,
                extraInfo: &extraInfo,
                suggestionLineLimit: ExpandableSuggestionService.shared.isSuggestionExpanded ? nil : 1
            )
            
            presenter.discardSuggestion(fileURL: fileURL)
            
            return .init(
                content: String(lines.joined(separator: "")),
                newSelection: .cursor(cursorPosition),
                modifications: extraInfo.modifications
            )
        }
        
        return nil
    }

    func presentRealtimeSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            try? await prepareCache(editor: editor)
        }
        return nil
    }

    @WorkspaceActor
    func prepareCache(editor: EditorContent) async throws -> UpdatedContent? {
        guard let fileURL = await XcodeInspector.shared.safe.realtimeActiveDocumentURL
        else { return nil }
        let (_, filespace) = try await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
        filespace.codeMetadata.uti = editor.uti
        filespace.codeMetadata.tabSize = editor.tabSize
        filespace.codeMetadata.indentSize = editor.indentSize
        filespace.codeMetadata.usesTabsForIndentation = editor.usesTabsForIndentation
        filespace.codeMetadata.guessLineEnding(from: editor.lines.first)
        return nil
    }

    func generateRealtimeSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        return try await presentSuggestions(editor: editor)
    }
}

