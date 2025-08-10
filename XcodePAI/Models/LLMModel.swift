//
//  LLMModel.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/9.
//

import Foundation

class LLMModel {
    let id: String
    let object: String
    let created: Int // Create Timestamp
    
    init(id: String, object: String, created: Int = Int(Date().timeIntervalSince1970)) {
        self.id = id
        self.object = object
        self.created = created
    }
}

class ChatProxyLLMModel: LLMModel {
    let provider: String = Constraint.AppName
    
    init(id: String, created: Int = Int(Date().timeIntervalSince1970)) {
        super.init(id: id, object: "model", created: created)
    }
    
    public func toDictionary() -> [String: Any] {
        return ["id": id, "object": object, "created": created, "owned_by": provider]
    }
}
