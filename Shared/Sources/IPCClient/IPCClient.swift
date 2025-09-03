//
//  IPCClient.swift
//  Shared
//
//  Created by Bill Cheng on 2025/9/4.
//

import Foundation
import IPCShared
import SuggestionBasic

public enum IPCExtensionServiceError: Swift.Error, LocalizedError {
    case failedToGetServiceEndpoint
    case failedToCreateIPCConnection
    case xpcServiceError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .failedToGetServiceEndpoint:
            return "Waiting for service to connect to the communication bridge."
        case .failedToCreateIPCConnection:
            return "Failed to create IPC connection."
        case let .xpcServiceError(error):
            return "Connection to extension service error: \(error.localizedDescription)"
        }
    }
}

public class IPCClient {
    
    @MainActor public static let shared = IPCClient()
    
    private lazy var wormhole: IPCWormhole? = {
        let wormhole = try? IPCWormhole(groupID: groupBundleId)
        return wormhole
    }()
    
    private func suggestionRequest(
        _ editorContent: EditorContent,
        _ id: String
    ) async throws -> UpdatedContent? {
        let data = try JSONEncoder().encode(editorContent)
        guard let wormhole else {
            throw IPCExtensionServiceError.failedToCreateIPCConnection
        }
        
        let updatedData = try await wormhole.sendDataMessageWithReply(message: data, identifier: id)
        
        return try JSONDecoder().decode(UpdatedContent.self, from: updatedData)
    }
    
}

public extension IPCClient {
    func getSuggestedCode(editorContent: EditorContent) async throws -> UpdatedContent? {
        try await suggestionRequest(
            editorContent,
            "getSuggestedCode"
        )
    }
    
    func getNextSuggestedCode(editorContent: EditorContent) async throws -> UpdatedContent? {
        try await suggestionRequest(
            editorContent,
            "getNextSuggestedCode"
        )
    }
    
    func getPreviousSuggestedCode(editorContent: EditorContent) async throws
    -> UpdatedContent?
    {
        try await suggestionRequest(
            editorContent,
            "getPreviousSuggestedCode"
        )
    }
    
    func getSuggestionAcceptedCode(editorContent: EditorContent) async throws
    -> UpdatedContent?
    {
        try await suggestionRequest(
            editorContent,
            "getSuggestionAcceptedCode"
        )
    }
    
    func getSuggestionRejectedCode(editorContent: EditorContent) async throws
    -> UpdatedContent?
    {
        try await suggestionRequest(
            editorContent,
            "getSuggestionRejectedCode"
        )
    }
    
    func getRealtimeSuggestedCode(editorContent: EditorContent) async throws
    -> UpdatedContent?
    {
        try await suggestionRequest(
            editorContent,
            "getRealtimeSuggestedCode"
        )
    }
    
    func toggleRealtimeSuggestion() throws {
        guard let wormhole else {
            throw IPCExtensionServiceError.failedToCreateIPCConnection
        }
        
        wormhole.sendDataMessage(Data(), identifier: "toggleRealtimeSuggestion")
    }
}
