//
//  LLMModelClient.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/13.
//

import Foundation

class LLMModelClient {
    
}

// MARK: Get Model List From Provider
extension LLMModelClient {
    static func getModelsList(_ provider: LLMModelProvider, complete: @escaping ([LLMModel]?, Error?) -> Void) {
        HTTPClient.get(url: provider.modelListUrl(), headers: provider.requestHeaders()) { result in
            switch result {
            case .success(let success):
                guard let json = try? JSONSerialization.jsonObject(with: success) as? [String: Any], let array = json["data"] as? [[String: Any]] else {
                    DispatchQueue.main.async {
                        complete(nil, nil)
                    }
                    return
                }
                
                var models = [LLMModel]()
                for object in array {
                    if let model = LLMModel(object, provider: provider.name) {
                        models.append(model)
                    }
                }
                
                DispatchQueue.main.async {
                    complete(models, nil)
                }
            case .failure(let failure):
                DispatchQueue.main.async {
                    complete(nil, failure)
                }
            }
        }
    }
}

// MARK: Model Test with completions
extension LLMModelClient {
    static func testModel(_ model: LLMModel, provider: LLMModelProvider, complete: @escaping (Bool) -> Void) {
        HTTPClient.post(url: provider.chatCompletionsUrl(), headers: provider.requestHeaders(), body: testData(model.id)) { result in
            switch result {
            case .success(let success):
                guard let json = try? JSONSerialization.jsonObject(with: success) as? [String: Any], let _ = json["id"] as? String else {
                    DispatchQueue.main.async {
                        complete(false)
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    complete(true)
                }
            case .failure(_):
                DispatchQueue.main.async {
                    complete(false)
                }
            }
        }
    }
    
    private static func testData(_ model: String) -> Data? {
        let request = LLMRequest(model: model, messages: [LLMMessage(role: "user", content: "hi")], stream: false)
        
        guard let data = try? JSONSerialization.data(withJSONObject: request.toDictionary()) else {
            return nil
        }
        
        return data
    }
}

struct LLMResponseUsageValue: Codable {
    let prompt_tokens: Int
    let completion_tokens: Int
    let total_tokens: Int
}

extension LLMModelClient {
    
    struct PrefixCompleteBody: Codable {
        let model: String
        let prompt: String
    }
    
    struct PrefixCompleteResponse: Codable {
        let choices: [PrefixCompleteResponseChoice]
        let usage: LLMResponseUsageValue
    }
    
    struct PrefixCompleteResponseChoice: Codable {
        let text: String
    }
    
    static let fimPrefix = "<|fim_prefix|>"
    static let fimSuffix = "<|fim_suffix|>"
    static let fimMiddle = "<|fim_middle|>"
    
    static func doCompletionRequest(_ model: LLMModel, provider: LLMModelProvider, prompt: String, suffix: String? = nil) async throws -> String? {
        let bodyPrompt: String = {
            if let suffix {
                return fimPrefix + prompt + fimSuffix + suffix + fimMiddle
            }
            return fimPrefix + prompt + fimSuffix
        }()
        
        let response: PrefixCompleteResponse = try await CoroutineHTTPClient.shared.post(provider.completionsUrl(), body: PrefixCompleteBody(model: model.id, prompt: bodyPrompt), headers: provider.requestHeaders())
        
        // TODO: Record token usages
        
        return response.choices.first?.text
    }
    
    static func doPartialCompletionRequest(_ model: LLMModel, provider: LLMModelProvider, prompt: String, system: String? = nil, instruction: String? = nil) async throws -> String? {
        
        var messages = [LLMMessage]()
        if let system {
            messages.append(LLMMessage(role: "system", content: system))
        }
        if let instruction {
            messages.append(LLMMessage(role: "user", content: instruction))
        }
        messages.append(try LLMMessage(role: "assistant", content: prompt, partial: true))
        
        let request = LLMRequest(model: model.id, messages:messages, stream: false)
        
        guard let data = try? JSONSerialization.data(withJSONObject: request.toDictionary()) else {
            throw CoroutineHTTPClientError.encodingError
        }
        
        let retData = try await CoroutineHTTPClient.POST(urlString: provider.chatCompletionsUrl(), headers: provider.requestHeaders(), body: data)
        
        guard let jsonDict = try? JSONSerialization.jsonObject(with: retData) as? [String: Any] else {
            throw CoroutineHTTPClientError.decodingError
        }
        
        let response = try LLMResponse(dict: jsonDict)
        
        // TODO: Record token usages
        
        return response.choices.first?.message.content
    }
    
}
