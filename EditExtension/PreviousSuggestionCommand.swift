import IPCClient
import Foundation
import SuggestionBasic
import XcodeKit

class PreviousSuggestionCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Previous Suggestion" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        completionHandler(nil)
        Task {
            _ = try await IPCClient.shared.getPreviousSuggestedCode(editorContent: .init(invocation))
        }
    }
}

