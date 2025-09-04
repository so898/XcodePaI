import Foundation
import Workspace
public final class KeyBindingManager {
    let tabToAcceptSuggestion: TabToAcceptSuggestion
    public init(
        workspacePool: WorkspacePool,
        acceptSuggestion: @escaping () -> Void,
        expandSuggestion: @escaping () -> Void,
        collapseSuggestion: @escaping () -> Void,
        dismissSuggestion: @escaping () -> Void
    ) {
        tabToAcceptSuggestion = .init(
            workspacePool: workspacePool,
            acceptSuggestion: acceptSuggestion,
            dismissSuggestion: dismissSuggestion, 
            expandSuggestion: expandSuggestion,
            collapseSuggestion: collapseSuggestion
        )
    }

    public func start() {
        tabToAcceptSuggestion.start()
    }
    
    @MainActor
    public func stopForExit() {
        tabToAcceptSuggestion.stopForExit()
    }
}
