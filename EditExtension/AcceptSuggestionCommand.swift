import SuggestionBasic
import Foundation
import XcodeKit
import IPCClient

class AcceptSuggestionCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Accept Suggestion" }
    
    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                try await (Task(timeout: 7) {
                    if let content = try await IPCClient.shared.getSuggestionAcceptedCode(
                        editorContent: .init(invocation)
                    ) {
                        invocation.accept(content)
                    }
                    completionHandler(nil)
                }.value)
            } catch is CancellationError {
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }
}
