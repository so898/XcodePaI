import IPCClient
import Foundation
import SuggestionBasic
import XcodeKit

class RejectSuggestionCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Decline Suggestion" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        completionHandler(nil)
        Task {
            _ = try await IPCClient.shared.getSuggestionRejectedCode(editorContent: .init(invocation))
        }
    }
}

