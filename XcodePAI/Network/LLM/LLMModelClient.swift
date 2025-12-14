//
//  LLMModelClient.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/13.
//

import Foundation

class LLMModelClient {
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
    
    private struct ModelListResponse: Codable {
        let data: [LLMResponseModel]
    }
    
    static func getModelsList(_  provider: LLMModelProvider) async throws -> [LLMModel] {
        let response: ModelListResponse = try await CoroutineHTTPClient.shared.GET(provider.modelListUrl(), headers: provider.requestHeaders())
        return response.data.map { model in
            return LLMModel(model, provider: provider.name)
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
