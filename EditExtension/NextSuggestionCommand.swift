import IPCClient
import Foundation
import SuggestionBasic
import XcodeKit

class NextSuggestionCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Next Suggestion" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        completionHandler(nil)
        Task {
            _ = try await IPCClient.shared.getNextSuggestedCode(editorContent: .init(invocation))
        }
    }
}

