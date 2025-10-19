//
//  TokenUsageRecord.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/10/19.
//

import Foundation
import SQLite

// Token Record - DB Model
struct TokenUsageRecord {
    let id: Int64?
    let timestamp: Date
    let provider: String
    let modelName: String
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
    let metadata: String? // JSON to storage prompt text
    
    init(
        id: Int64? = nil,
        timestamp: Date = Date(),
        provider: String,
        modelName: String,
        inputTokens: Int,
        outputTokens: Int,
        metadata: [String: Any]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.provider = provider
        self.modelName = modelName
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = inputTokens + outputTokens
        
        if let metadata = metadata,
           let jsonData = try? JSONSerialization.data(withJSONObject: metadata),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            self.metadata = jsonString
        } else {
            self.metadata = nil
        }
    }
    
    // init from DB
    init?(row: Row, table: TokenUsageTable) {
        guard let timestamp = try? row.get(table.timestamp) else { return nil }
        
        do {
            self.id = try? row.get(table.id)
            self.timestamp = timestamp
            self.provider = try row.get(table.provider)
            self.modelName = try row.get(table.modelName)
            self.inputTokens = try row.get(table.inputTokens)
            self.outputTokens = try row.get(table.outputTokens)
            self.totalTokens = try row.get(table.totalTokens)
            self.metadata = try? row.get(table.metadata)
        } catch {
            return nil
        }
    }
    
    // Get metadata info
    func getMetadata() -> [String: Any]? {
        guard let metadataString = metadata,
              let data = metadataString.data(using: .utf8),
              let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dictionary
    }
}

// DB Table Definition
struct TokenUsageTable {
    let table = Table("token_usage_records")
    
    let id = Expression<Int64>("id")
    let timestamp = Expression<Date>("timestamp")
    let provider = Expression<String>("model_provider")
    let modelName = Expression<String>("model_name")
    let inputTokens = Expression<Int>("input_tokens")
    let outputTokens = Expression<Int>("output_tokens")
    let totalTokens = Expression<Int>("total_tokens")
    let metadata = Expression<String?>("metadata")
    
    func createTable(db: Connection) throws {
        try db.run(table.create(ifNotExists: true) { t in
            t.column(id, primaryKey: .autoincrement)
            t.column(timestamp)
            t.column(provider)
            t.column(modelName)
            t.column(inputTokens)
            t.column(outputTokens)
            t.column(totalTokens)
            t.column(metadata)
        })
        
        // Create index to optimize query performance
        try db.run(table.createIndex(timestamp, ifNotExists: true))
        try db.run(table.createIndex(provider, ifNotExists: true))
        try db.run(table.createIndex(modelName, ifNotExists: true))
    }
}
