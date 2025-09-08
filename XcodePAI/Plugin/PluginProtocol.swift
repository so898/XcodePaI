//
//  PluginProtocol.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/9/9.
//

import Foundation

/// Base protocol for all plugins
///
/// This protocol defines the basic requirements for any plugin to be integrated into the XcodePAI system.
/// It includes essential properties such as `identifier`, `name`, and `version`, which help in uniquely identifying and managing the plugin.
///
/// Conforming to this protocol ensures that each plugin provides necessary metadata and can be instantiated without parameters.
///
/// Example usage:
/// ```swift
/// class MyPlugin: NSObject, BasePluginProtocol {
///     static let identifier = "com.example.myplugin"
///     static let name = "My Plugin"
///     static let description = "A simple plugin"
///     static let version = "1.0.0"
///
///     required override init() {
///         super.init()
///         // Initialization code here
///     }
/// }
/// ```
///
/// - SeeAlso: `ChatPluginProtocol`
///
@objc protocol BasePluginProtocol {
    /// The Identifier of the plugin
    static var identifier: String { get }
    /// The display name of the plugin, which will be shown in plugin list
    static var name: String { get }
    /// The display description of the plugin, which will be shown in plugin list
    static var description: String { get }
    /// The version of the plugin
    static var version: String { get }
    
    init()
}

/// Protocol for plugins that modify chat prompts
///
/// This protocol allows plugins to intercept and modify system, user, and assistant prompts before they are sent to the chat completions service.
///
/// Conforming to this protocol enables a plugin to:
/// - Modify the system prompt to set specific rules or guidelines for the chat.
/// - Adjust the user prompt to refine or enhance the user's input.
/// - Alter the assistant prompt to guide or correct the assistant's response.
///
/// Implementations should provide logic for each method to determine whether modifications are necessary and return the modified prompt or `nil` if no changes are needed.
///
/// Example usage:
/// ```swift
/// class MyChatPlugin: NSObject, ChatPluginProtocol {
///     func processSystemPrompt(_ prompt: String) -> String? {
///         // Add custom rules or guidelines
///         return "You are a helpful assistant. \(prompt)"
///     }
///
///     func processUserPrompt(_ prompt: String, isLast: Bool) -> String? {
///         // Refine or enhance user input
///         return prompt.capitalized
///     }
///
///     func processAssistantPrompt(_ prompt: String, isLast: Bool) -> String? {
///         // Guide or correct assistant response
///         return prompt.replacingOccurrences(of: "wrong", with: "correct")
///     }
/// }
/// ```
///
/// Note: Ensure that the plugin is properly registered and loaded by the application to take effect.
///
/// - SeeAlso: `BasePluginProtocol`
///
@objc protocol ChatPluginProtocol {
    
    /// Update system prompt of the chat completions request
    /// Parameters
    /// - prompt: The original system prompt
    /// Returns
    /// - The updated system prompt or nil if no change is needed
    func processSystemPrompt(_ prompt: String) -> String?
    
    /// Update user prompt of the chat completions request
    /// Parameters
    /// - prompt: The original user prompt
    /// - isLast: Whether this is the last chunk of the user request
    /// Returns
    /// - The updated user prompt or nil if no change is needed
    func processUserPrompt(_ prompt: String, isLast: Bool) -> String?
    
    /// Update assistant prompt of the chat completions request
    /// Parameters
    /// - prompt: The original assistant prompt
    /// - isLast: Whether this is the last chunk of the assistant response
    /// Returns
    /// - The updated assistant prompt or nil if no change is needed
    func processAssistantPrompt(_ prompt: String, isLast: Bool) -> String?
}

/// Protocol for plugins that generate code suggestions
///
/// This protocol allows plugins to generate additional context or suggestions for code completion based on the current file and code context.
///
/// Conforming to this protocol enables a plugin to:
/// - Provide additional information or context that can be used in prefix completions requests.
/// - Provide additional information or context that can be included in the user prompt for partial chat completions.
///
/// Implementations should provide logic to generate the necessary context or suggestions based on the provided parameters.
///
/// Example usage:
/// ```swift
/// class MyCodeSuggestionPlugin: NSObject, CodeSuggestionProtocol {
///     func generateCodeSuggestionsContext(forFile file: String, code: String, prefix: String?, suffix: String?) -> String? {
///         // Generate context based on file and code
///         return "Additional context for \(file)\nCurrent code snippet: \(prefix ?? "")[cursor]\(suffix ?? "")"
///     }
/// }
/// ```
///
/// Note: Ensure that the plugin is properly registered and loaded by the application to take effect.
///
/// - SeeAlso: `BasePluginProtocol`
///
@objc protocol CodeSuggestionProtocol {
    
    /// Generate code suggestions context based on the current file and code context
    /// The context will be used as the comment at the top of the code source in prefix completions request
    /// Or will be used in the user prompt for partial chat completions request
    /// Parameters
    /// - file: The path of the current file
    /// - code: The current code content
    /// - prefix: The prefix text before the cursor (optional)
    /// - suffix: The suffix text after the cursor (optional)
    /// Returns
    /// - The generated content for code suggestions or nil if no suggestions are available
    func generateCodeSuggestionsContext(forFile file: String, code: String, prefix: String?, suffic: String?) -> String?
}
