//
//  RecordStorage.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/10/19.
//

import Foundation
import SQLite
import Logger

class RecordStorage {
    private let db: Connection
    private let tokenTable = TokenUsageTable()
    
    init() throws {
        // Database location
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folderName = Bundle.main.object(forInfoDictionaryKey: "APPLICATION_SUPPORT_FOLDER") as! String
        let recordURL = appSupportURL.appendingPathComponent("\(folderName)/Records")
        
        // Make directory if not exist
        if !fileManager.fileExists(atPath: recordURL.path) {
            try fileManager.createDirectory(at: recordURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        let dbPath = recordURL.appendingPathComponent("Usage_Record.db")
        
        // Create DB connection
        db = try Connection(dbPath.path)
        
        // Create table
        try tokenTable.createTable(db: db)
    }
    
    func saveRecord(_ record: TokenUsageRecord) throws -> Int64{
        let insert = tokenTable.table.insert(
            tokenTable.timestamp <- record.timestamp,
            tokenTable.provider <- record.provider,
            tokenTable.modelName <- record.modelName,
            tokenTable.inputTokens <- record.inputTokens,
            tokenTable.outputTokens <- record.outputTokens,
            tokenTable.totalTokens <- record.totalTokens,
            tokenTable.isCompletion <- record.isCompletion,
            tokenTable.completionAccepted <- record.completionAccepted,
            tokenTable.metadata <- record.metadata
        )
        
        return try db.run(insert)
    }
    
    func updateRecordCompletionAccept(_ id: Int64, accpet: Bool = true) {
        do {
            let recordRow = tokenTable.table.filter(tokenTable.id == id)
            try db.run(
                recordRow.update(
                    tokenTable.completionAccepted <- accpet
                )
            )
        } catch let err {
            Logger.storage.error(err)
        }
    }
    
    func loadRecords(
        from startDate: Date? = nil,
        to endDate: Date? = nil,
        provider: String? = nil,
        modelName: String? = nil,
        isCompletion: Bool? = nil,
        limit: Int? = nil
    ) -> [TokenUsageRecord] {
        var query = tokenTable.table
        
        // Filter with date
        if let startDate = startDate {
            query = query.filter(tokenTable.timestamp >= startDate)
        }
        if let endDate = endDate {
            query = query.filter(tokenTable.timestamp <= endDate)
        }
        
        if let provider = provider {
            query = query.filter(tokenTable.provider == provider)
        }
        
        if let modelName = modelName {
            query = query.filter(tokenTable.modelName == modelName)
        }
        
        if let isCompletion = isCompletion {
            query = query.filter(tokenTable.isCompletion == isCompletion)
        }
        
        // Order result
        query = query.order(tokenTable.timestamp.desc)
        
        // Limit
        if let limit = limit {
            query = query.limit(limit)
        }
        
        do {
            let rows = try db.prepare(query)
            return rows.compactMap { TokenUsageRecord(row: $0, table: tokenTable) }
        } catch {
            Logger.storage.error("Failed to load records: \(error.localizedDescription)")
            return []
        }
    }
    
    func getTotalUsage(
        from startDate: Date? = nil,
        to endDate: Date? = nil,
        provider: String? = nil,
        modelName: String? = nil,
        isCompletion: Bool? = nil
    ) -> (inputTokens: Int, outputTokens: Int, totalTokens: Int, count: Int) {
        var query = tokenTable.table
        
        // Apply filter
        if let startDate = startDate {
            query = query.filter(tokenTable.timestamp >= startDate)
        }
        if let endDate = endDate {
            query = query.filter(tokenTable.timestamp <= endDate)
        }
        if let provider = provider {
            query = query.filter(tokenTable.provider == provider)
        }
        if let modelName = modelName {
            query = query.filter(tokenTable.modelName == modelName)
        }
        
        if let isCompletion = isCompletion {
            query = query.filter(tokenTable.isCompletion == isCompletion)
        }
        
        do {
            let inputTokens = try db.scalar(query.select(tokenTable.inputTokens.sum)) ?? 0
            let outputTokens = try db.scalar(query.select(tokenTable.outputTokens.sum)) ?? 0
            let totalTokens = try db.scalar(query.select(tokenTable.totalTokens.sum)) ?? 0
            let count = try db.scalar(query.select(tokenTable.id.count))
            
            return (inputTokens, outputTokens, totalTokens, count)
        } catch {
            Logger.storage.error("Failed to get total usage: \(error.localizedDescription)")
            return (0, 0, 0, 0)
        }
    }
    
    func getModelBreakdown(
        from startDate: Date? = nil,
        to endDate: Date? = nil
    ) -> [String: (inputTokens: Int, outputTokens: Int, totalTokens: Int, count: Int)] {
        var query = tokenTable.table
        
        if let startDate = startDate {
            query = query.filter(tokenTable.timestamp >= startDate)
        }
        if let endDate = endDate {
            query = query.filter(tokenTable.timestamp <= endDate)
        }
        
        do {
            let rows = try db.prepare(query)
            var breakdown: [String: (inputTokens: Int, outputTokens: Int, totalTokens: Int, count: Int)] = [:]
            
            for row in rows {
                guard let record = TokenUsageRecord(row: row, table: tokenTable) else { continue }
                
                let current = breakdown[record.modelName] ?? (0, 0, 0, 0)
                breakdown[record.modelName] = (
                    current.inputTokens + record.inputTokens,
                    current.outputTokens + record.outputTokens,
                    current.totalTokens + record.totalTokens,
                    current.count + 1
                )
            }
            
            return breakdown
        } catch {
            Logger.storage.error("Failed to get model breakdown: \(error.localizedDescription)")
            return [:]
        }
    }
    
    func cleanupOldRecords(olderThan timeInterval: TimeInterval) throws {
        let cutoffDate = Date().addingTimeInterval(-timeInterval)
        let deleteQuery = tokenTable.table.filter(tokenTable.timestamp < cutoffDate)
        
        try db.run(deleteQuery.delete())
    }
    
    func getDatabaseSize() -> Int64? {
        do {
            let statement = try db.prepare("PRAGMA page_count;")
            let pageCount = try statement.scalar() as? Int64 ?? 0
            
            let statement2 = try db.prepare("PRAGMA page_size;")
            let pageSize = try statement2.scalar() as? Int64 ?? 0
            
            return pageCount * pageSize
        } catch {
            Logger.storage.error("Failed to get database size: \(error.localizedDescription)")
            return nil
        }
    }
}
