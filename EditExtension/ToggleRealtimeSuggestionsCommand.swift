import IPCClient
import SuggestionBasic
import Foundation
import XcodeKit

class ToggleRealtimeSuggestionsCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Enable/Disable Completions" }

    func perform(
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
