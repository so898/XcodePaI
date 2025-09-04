import IPCClient
import SuggestionBasic
import Foundation
import XcodeKit

class SyncTextSettingsCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Sync Text Settings" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        completionHandler(nil)
        Task {
            _ = try await IPCClient.shared.getRealtimeSuggestedCode(editorContent: .init(invocation))
        }
    }
}
