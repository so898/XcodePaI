//
//  IPCSuggestionBridge.swift
//  ThirdPartyCore
//
//  Created by Bill Cheng on 9/5/25.
//

import Foundation
import SuggestionBasic
import Logger

public class IPCSuggestionBridge {
    @discardableResult
    public static func replyWithUpdatedContent(
        editorContent: EditorContent,
        file: StaticString = #file,
        line: UInt = #line,
        isRealtimeSuggestionRelatedCommand: Bool = false,
        withReply reply: @escaping (UpdatedContent?, Error?) -> Void,
        getUpdatedContent: @escaping @ServiceActor (
            SuggestionCommandHandler,
            EditorContent
        ) async throws -> UpdatedContent?
    ) -> Task<Void, Never> {
        let task = Task {
            do {
                let handler: SuggestionCommandHandler = WindowBaseCommandHandler()
                try Task.checkCancellation()
                guard let updatedContent = try await getUpdatedContent(handler, editorContent) else {
                    reply(nil, nil)
                    return
                }
                try Task.checkCancellation()
                try reply(updatedContent, nil)
            } catch {
                Logger.service.error("\(file):\(line) \(error.localizedDescription)")
                reply(nil, NSError.from(error))
            }
        }

        Task {
            await Service.shared.realtimeSuggestionController.cancelInFlightTasks(excluding: task)
        }
        return task
    }
}
