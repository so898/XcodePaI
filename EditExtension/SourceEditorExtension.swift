//
//  SourceEditorExtension.swift
//  EditExtension
//
//  Created by Bill Cheng on 2025/9/2.
//

import Foundation
import XcodeKit

class SourceEditorExtension: NSObject, XCSourceEditorExtension {
    
    var commandDefinitions: [[XCSourceEditorCommandDefinitionKey: Any]] {
        [
            AcceptSuggestionCommand(),
            RejectSuggestionCommand(),
            GetSuggestionsCommand(),
            NextSuggestionCommand(),
            PreviousSuggestionCommand(),
            ToggleRealtimeSuggestionsCommand(),
            SyncTextSettingsCommand(),
        ].map(makeCommandDefinition)
    }
    
    func extensionDidFinishLaunching() {
        print("Xcode Source Edit Extension Started.")
    }
}

let identifierPrefix: String = Bundle.main.bundleIdentifier ?? ""

var customCommandMap = [String: String]()

protocol CommandType: AnyObject {
    var commandClassName: String { get }
    var identifier: String { get }
    var name: String { get }
}

extension CommandType where Self: NSObject {
    var commandClassName: String { Self.className() }
    var identifier: String { commandClassName }
}

extension CommandType {
    func makeCommandDefinition() -> [XCSourceEditorCommandDefinitionKey: Any] {
        [.classNameKey: commandClassName,
         .identifierKey: identifierPrefix + identifier,
         .nameKey: name]
    }
}

func makeCommandDefinition(_ commandType: CommandType)
-> [XCSourceEditorCommandDefinitionKey: Any]
{
    commandType.makeCommandDefinition()
}
