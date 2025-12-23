//
//  IPCServer.swift
//  Shared
//
//  Created by Bill Cheng on 2025/9/4.
//

import Foundation
import IPCShared
import GitHubCopilotService
import Service
import SuggestionBasic

public class IPCServer {
    
    @MainActor public static let shared = IPCServer()
    
    private lazy var wormhole: IPCWormhole? = {
        let wormhole = try? IPCWormhole(groupID: groupBundleId)
        return wormhole
    }()
    
    public init() {
        wormhole?.listenMessage(for: "getSuggestedCode") {[weak self] (editorContent: EditorContent, reply) in
            guard let `self` = self else { return }
            self.getSuggestedCode(editorContent: editorContent) { updatedContent, _ in
                reply(updatedContent)
            }
        }
        wormhole?.listenMessage(for: "getNextSuggestedCode") {[weak self] (editorContent: EditorContent, reply) in
            guard let `self` = self else { return }
            self.getNextSuggestedCode(editorContent: editorContent) { updatedContent, _ in
                reply(updatedContent)
            }
        }
        wormhole?.listenMessage(for: "getPreviousSuggestedCode") {[weak self] (editorContent: EditorContent, reply) in
            guard let `self` = self else { return }
            self.getPreviousSuggestedCode(editorContent: editorContent) { updatedContent, _ in
                reply(updatedContent)
            }
        }
        wormhole?.listenMessage(for: "getSuggestionAcceptedCode") {[weak self] (editorContent: EditorContent, reply) in
            guard let `self` = self else { return }
            self.getSuggestionAcceptedCode(editorContent: editorContent) { updatedContent, _ in
                reply(updatedContent)
            }
        }
        wormhole?.listenMessage(for: "getSuggestionRejectedCode") {[weak self] (editorContent: EditorContent, reply) in
            guard let `self` = self else { return }
            self.getSuggestionRejectedCode(editorContent: editorContent) { updatedContent, _ in
                reply(updatedContent)
            }
        }
        wormhole?.listenMessage(for: "getRealtimeSuggestedCode") {[weak self] (editorContent: EditorContent, reply) in
            guard let `self` = self else { return }
            self.getRealtimeSuggestedCode(editorContent: editorContent) { updatedContent, _ in
                reply(updatedContent)
            }
        }
        wormhole?.listenMessage(for: "toggleRealtimeSuggestion") {[weak self] (editorContent: EditorContent, reply) in
            guard let `self` = self else { return }
            self.toggleRealtimeSuggestion { _ in
                reply(nil)
            }
        }
        wormhole?.listenMessage(for: "gitCommit") {[weak self] (_: Data, reply) in
            guard let `self` = self else { return }
            self.gitCommit { _ in
                reply(nil)
            }
        }
        
    }
}

extension IPCServer {
    public func getSuggestedCode(editorContent: EditorContent, withReply reply: @escaping (_ updatedContent: UpdatedContent?, Error?) -> Void) {
        print("getSuggestedCode")
        
        IPCSuggestionBridge.replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.presentSuggestions(editor: editor)
        }
    }
    
    public func getNextSuggestedCode(editorContent: EditorContent, withReply reply: @escaping (_ updatedContent: UpdatedContent?, Error?) -> Void) {
        print("getNextSuggestedCode")
        IPCSuggestionBridge.replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.presentNextSuggestion(editor: editor)
        }
    }
    
    public func getPreviousSuggestedCode(editorContent: EditorContent, withReply reply: @escaping (_ updatedContent: UpdatedContent?, Error?) -> Void) {
        print("getPreviousSuggestedCode")
        IPCSuggestionBridge.replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.presentPreviousSuggestion(editor: editor)
        }
    }
    
    public func getSuggestionAcceptedCode(editorContent: EditorContent, withReply reply: @escaping (_ updatedContent: UpdatedContent?, Error?) -> Void) {
        print("getSuggestionAcceptedCode")
        IPCSuggestionBridge.replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.acceptSuggestion(editor: editor)
        }
    }
    
    public func getSuggestionRejectedCode(editorContent: EditorContent, withReply reply: @escaping (_ updatedContent: UpdatedContent?, Error?) -> Void) {
        print("getSuggestionRejectedCode")
        IPCSuggestionBridge.replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.rejectSuggestion(editor: editor)
        }
    }
    
    public func getRealtimeSuggestedCode(editorContent: EditorContent, withReply reply: @escaping (UpdatedContent?, Error?) -> Void) {
        print("getRealtimeSuggestedCode")
        IPCSuggestionBridge.replyWithUpdatedContent(
            editorContent: editorContent,
            isRealtimeSuggestionRelatedCommand: true,
            withReply: reply
        ) { handler, editor in
            try await handler.presentRealtimeSuggestions(editor: editor)
        }
    }
    
    public func toggleRealtimeSuggestion(withReply reply: @escaping (Error?) -> Void) {
        print("toggleRealtimeSuggestion")
        reply(nil)
    }
    
    public func gitCommit(withReply reply: @escaping (Error?) -> Void) {
        print("gitCommit")
        NotificationCenter.default.post(name: .init(rawValue: "OpenNewGitCommitWindow"), object: nil)
        reply(nil)
    }
}
