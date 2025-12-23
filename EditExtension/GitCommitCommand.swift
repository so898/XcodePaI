//
//  GitCommitCommand.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/12/23.
//

import IPCClient
import SuggestionBasic
import Foundation
import XcodeKit

class GitCommitCommand: NSObject, @MainActor XCSourceEditorCommand, CommandType {
    var name: String { "Git Commit" }
    
    @MainActor func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        do {
            try IPCClient.shared.gitCommit()
            completionHandler(nil)
        } catch is CancellationError {
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }
}
