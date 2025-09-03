import IPCClient
import Foundation
import SuggestionBasic
import XcodeKit

class GetSuggestionsCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Get Suggestions" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        completionHandler(nil)
        Task {
            _ = try await IPCClient.shared.getSuggestedCode(editorContent: .init(invocation))
        }
    }
}

