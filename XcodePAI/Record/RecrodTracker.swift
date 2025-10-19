//
//  RecrodTracker.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/10/19.
//

import Foundation

class RecordTracker {
    static let shared: RecordTracker = {
        do {
            return try RecordTracker()
        } catch {
            fatalError("Failed to initialize TokenUsageTracker: \(error)")
        }
    }()
    
    private let storage: RecordStorage
    private let analytics: TokenUsageAnalytics
    
    private init() throws {
        self.storage = try RecordStorage()
        self.analytics = TokenUsageAnalytics(storage: storage)
    }
    
    func recordTokenUsage(
        modelProvider: String,
        modelName: String,
        inputTokens: Int,
        outputTokens: Int,
        apiEndpoint: String,
        userId: String? = nil,
        metadata: [String: Any]? = nil
    ) {
        do {
            let record = TokenUsageRecord(
                provider: modelProvider,
                modelName: modelName,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                metadata: metadata
            )
            
            try storage.saveRecord(record)
        } catch {
            print("Failed to record token usage: \(error)")
        }
    }
    
    func recordTokenUsages(_ records: [TokenUsageRecord]) {
        do {
            for record in records {
                try storage.saveRecord(record)
            }
        } catch {
            print("Failed to record token usages: \(error)")
        }
    }
    
    func getSummary(for period: DateInterval) -> TokenUsageSummary {
        return analytics.generateSummary(for: period)
    }
    
    func getTodaySummary() -> TokenUsageSummary {
        let calendar = Calendar.current
        let today = calendar.dateInterval(of: .day, for: Date())!
        return getSummary(for: today)
    }
    
    func getThisMonthSummary() -> TokenUsageSummary {
        let calendar = Calendar.current
        let month = calendar.dateInterval(of: .month, for: Date())!
        return getSummary(for: month)
    }
    
    func getModelSummary(modelName: String, for period: DateInterval) -> TokenUsageSummary? {
        let usage = storage.getTotalUsage(from: period.start, to: period.end, modelName: modelName)
        guard usage.count > 0 else { return nil }
        
        return TokenUsageSummary(
            period: period,
            totalInputTokens: usage.inputTokens,
            totalOutputTokens: usage.outputTokens,
            totalTokens: usage.totalTokens,
            averageInputTokens: Double(usage.inputTokens) / Double(usage.count),
            averageOutputTokens: Double(usage.outputTokens) / Double(usage.count),
            requestCount: usage.count,
            modelBreakdown: [:]
        )
    }
    
    func getHourlyUsage(for date: Date) -> [Int: TokenUsageSummary] {
        return analytics.getHourlyUsage(for: date)
    }
    
//    func getTopUsers(limit: Int = 10, from startDate: Date? = nil, to endDate: Date? = nil) -> [(userId: String, usage: TokenUsageSummary)] {
//        return analytics.getTopUsers(limit: limit, from: startDate, to: endDate)
//    }
    
    // Remove old records
    func cleanupOldRecords(keepDays: Int = 90) {
        let timeInterval = TimeInterval(keepDays * 24 * 60 * 60)
        do {
            try storage.cleanupOldRecords(olderThan: timeInterval)
        } catch {
            print("Failed to cleanup old records: \(error)")
        }
    }
    
    func getDatabaseInfo() -> (size: Int64?, recordCount: Int) {
        let size = storage.getDatabaseSize()
        let records = storage.loadRecords(limit: 1) // Only count
        return (size, records.count)
    }
}
