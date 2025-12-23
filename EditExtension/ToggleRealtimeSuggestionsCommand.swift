import IPCClient
import SuggestionBasic
import Foundation
import XcodeKit

class ToggleRealtimeSuggestionsCommand: NSObject, @MainActor XCSourceEditorCommand, CommandType {
    var name: String { "Enable/Disable Completions" }

    @MainActor func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        do {
            try IPCClient.shared.toggleRealtimeSuggestion()
            completionHandler(nil)
        } catch is CancellationError {
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }
}
