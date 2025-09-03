//
//  IPCServer.swift
//  Shared
//
//  Created by Bill Cheng on 2025/9/4.
//

import Foundation
import IPCShared

public class IPCServer {
    
    @MainActor public static let shared = IPCServer()
    
    private lazy var wormhole: IPCWormhole? = {
        let wormhole = try? IPCWormhole(groupID: groupBundleId)
        return wormhole
    }()
    
    public init() {
        wormhole?.listenDataMessage(for: "getSuggestedCode") {[weak self] data, reply in
            guard let `self` = self else { return }
            self.getSuggestedCode(editorContent: data) { updatedContent, _ in
                reply(updatedContent)
            }
        }
        wormhole?.listenDataMessage(for: "getNextSuggestedCode") {[weak self] data, reply in
            guard let `self` = self else { return }
            self.getNextSuggestedCode(editorContent: data) { updatedContent, _ in
                reply(updatedContent)
            }
        }
        wormhole?.listenDataMessage(for: "getPreviousSuggestedCode") {[weak self] data, reply in
            guard let `self` = self else { return }
            self.getPreviousSuggestedCode(editorContent: data) { updatedContent, _ in
                reply(updatedContent)
            }
        }
        wormhole?.listenDataMessage(for: "getSuggestionAcceptedCode") {[weak self] data, reply in
            guard let `self` = self else { return }
            self.getSuggestionAcceptedCode(editorContent: data) { updatedContent, _ in
                reply(updatedContent)
            }
        }
        wormhole?.listenDataMessage(for: "getSuggestionRejectedCode") {[weak self] data, reply in
            guard let `self` = self else { return }
            self.getSuggestionRejectedCode(editorContent: data) { updatedContent, _ in
                reply(updatedContent)
            }
        }
        wormhole?.listenDataMessage(for: "getRealtimeSuggestedCode") {[weak self] data, reply in
            guard let `self` = self else { return }
            self.getRealtimeSuggestedCode(editorContent: data) { updatedContent, _ in
                reply(updatedContent)
            }
        }
        wormhole?.listenDataMessage(for: "toggleRealtimeSuggestion") {[weak self] data, reply in
            guard let `self` = self else { return }
            self.toggleRealtimeSuggestion { _ in
                reply(nil)
            }
        }
        
        
    }
}

extension IPCServer {
    public func getSuggestedCode(editorContent: Data, withReply reply: @escaping (_ updatedContent: Data?, Error?) -> Void) {
        print("getSuggestedCode")
        reply(nil, nil)
    }
    
    public func getNextSuggestedCode(editorContent: Data, withReply reply: @escaping (_ updatedContent: Data?, Error?) -> Void) {
        print("getNextSuggestedCode")
        reply(nil, nil)
    }
    
    public func getPreviousSuggestedCode(editorContent: Data, withReply reply: @escaping (_ updatedContent: Data?, Error?) -> Void) {
        print("getPreviousSuggestedCode")
        reply(nil, nil)
    }
    
    public func getSuggestionAcceptedCode(editorContent: Data, withReply reply: @escaping (_ updatedContent: Data?, Error?) -> Void) {
        print("getSuggestionAcceptedCode")
        reply(nil, nil)
    }
    
    public func getSuggestionRejectedCode(editorContent: Data, withReply reply: @escaping (_ updatedContent: Data?, Error?) -> Void) {
        print("getSuggestionRejectedCode")
        reply(nil, nil)
    }
    
    public func getRealtimeSuggestedCode(editorContent: Data, withReply reply: @escaping (Data?, Error?) -> Void) {
        print("getRealtimeSuggestedCode")
        reply(nil, nil)
    }
    
    public func toggleRealtimeSuggestion(withReply reply: @escaping (Error?) -> Void) {
        print("toggleRealtimeSuggestion")
        reply(nil)
    }
    
}
