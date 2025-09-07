//
//  LLMCompletionClient.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/9/5.
//

import Foundation

struct LLMCompletionResponseUsageValue: Codable {
    let prompt_tokens: Int
    let completion_tokens: Int
    let total_tokens: Int
}

class LLMCompletionClient {
    
    struct RequestCompleteBody: Codable {
        let model: String
        let prompt: String
        let suffix: String?
    }
    
    struct PrefixCompleteResponse: Codable {
        let choices: [PrefixCompleteResponseChoice]
        let usage: LLMCompletionResponseUsageValue
    }
    
    struct PrefixCompleteResponseChoice: Codable {
        let text: String
    }
    
    static let fimPrefix = "<|fim_prefix|>"
    static let fimSuffix = "<|fim_suffix|>"
    static let fimMiddle = "<|fim_middle|>"
    
    static func doPromptCompletionRequest(_ model: LLMModel, provider: LLMModelProvider, prompt: String, suffix: String? = nil, headers: [String: String]? = nil) async throws -> String? {
        let bodyPrompt: String = {
            if let suffix {
                return fimPrefix + prompt + fimSuffix + suffix + fimMiddle
            }
            return fimPrefix + prompt + fimSuffix
        }()
        
        var requestHeaders = provider.requestHeaders()
        if let headers {
            headers.forEach { (key: String, value: String) in
                requestHeaders[key] = value
            }
        }
        
        let response: PrefixCompleteResponse = try await CoroutineHTTPClient.shared.post(provider.completionsUrl(), body: RequestCompleteBody(model: model.id, prompt: bodyPrompt, suffix: nil), headers: requestHeaders)
        
        // TODO: Record token usages
        
        return response.choices.first?.text
    }
    
    static func doPromptSuffixCompletionRequest(_ model: LLMModel, provider: LLMModelProvider, prompt: String, suffix: String? = nil, headers: [String: String]? = nil) async throws -> String? {
        var requestHeaders = provider.requestHeaders()
        if let headers {
            headers.forEach { (key: String, value: String) in
                requestHeaders[key] = value
            }
        }
        
        let response: PrefixCompleteResponse = try await CoroutineHTTPClient.shared.post(provider.completionsUrl(), body: RequestCompleteBody(model: model.id, prompt: prompt, suffix: suffix), headers: requestHeaders)
        
        // TODO: Record token usages
        
        return response.choices.first?.text
    }
    
    static func doPartialCompletionRequest(_ model: LLMModel, provider: LLMModelProvider, prompt: String, system: String? = nil, instruction: String? = nil, maxTokens: Int? = 1024, headers: [String: String]? = nil) async throws -> String? {
        
        var messages = [LLMMessage]()
        if let system {
            messages.append(LLMMessage(role: "system", content: system))
        }
        if let instruction {
            messages.append(LLMMessage(role: "user", content: instruction))
        }
        messages.append(try LLMMessage(role: "assistant", content: prompt, partial: true))
        
        let request = LLMRequest(model: model.id, messages:messages, stream: false, maxTokens: maxTokens)
        
        guard let data = try? JSONSerialization.data(withJSONObject: request.toDictionary()) else {
            throw CoroutineHTTPClientError.encodingError
        }
        
        var requestHeaders = provider.requestHeaders()
        if let headers {
            headers.forEach { (key: String, value: String) in
                requestHeaders[key] = value
            }
        }
        
        let retData = try await CoroutineHTTPClient.POST(urlString: provider.chatCompletionsUrl(), headers: requestHeaders, body: data)
        
        guard let jsonDict = try? JSONSerialization.jsonObject(with: retData) as? [String: Any] else {
            throw CoroutineHTTPClientError.decodingError
        }
        
        let response = try LLMResponse(dict: jsonDict)
        
        // TODO: Record token usages
        
        return response.choices.first?.message.content
    }
    
}
