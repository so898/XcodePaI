//
//  TokenUsageAnalytics.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/10/19.
//

import Foundation

struct TokenUsageSummary: Codable {
    let period: DateInterval
    let totalInputTokens: Int
    let totalOutputTokens: Int
    let totalTokens: Int
    let averageInputTokens: Double
    let averageOutputTokens: Double
    let requestCount: Int
    let modelBreakdown: [String: TokenUsageSummary]
}

class TokenUsageAnalytics {
    private let storage: RecordStorage
    
    init(storage: RecordStorage) {
        self.storage = storage
    }
    
    func generateSummary(for period: DateInterval) -> TokenUsageSummary {
        let usage = storage.getTotalUsage(from: period.start, to: period.end)
        let modelBreakdown = storage.getModelBreakdown(from: period.start, to: period.end)
            .mapValues { breakdown in
                TokenUsageSummary(
                    period: period,
                    totalInputTokens: breakdown.inputTokens,
                    totalOutputTokens: breakdown.outputTokens,
                    totalTokens: breakdown.totalTokens,
                    averageInputTokens: breakdown.count > 0 ? Double(breakdown.inputTokens) / Double(breakdown.count) : 0,
                    averageOutputTokens: breakdown.count > 0 ? Double(breakdown.outputTokens) / Double(breakdown.count) : 0,
                    requestCount: breakdown.count,
                    modelBreakdown: [:]
                )
            }
        
        return TokenUsageSummary(
            period: period,
            totalInputTokens: usage.inputTokens,
            totalOutputTokens: usage.outputTokens,
            totalTokens: usage.totalTokens,
            averageInputTokens: usage.count > 0 ? Double(usage.inputTokens) / Double(usage.count) : 0,
            averageOutputTokens: usage.count > 0 ? Double(usage.outputTokens) / Double(usage.count) : 0,
            requestCount: usage.count,
            modelBreakdown: modelBreakdown
        )
    }
    
    func getHourlyUsage(for date: Date) -> [Int: TokenUsageSummary] {
        let calendar = Calendar.current
        var hourlyUsage: [Int: TokenUsageSummary] = [:]
        
        for hour in 0..<24 {
            guard let hourStart = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date),
                  let hourEnd = calendar.date(bySettingHour: hour, minute: 59, second: 59, of: date) else {
                continue
            }
            
            let hourInterval = DateInterval(start: hourStart, end: hourEnd)
            let usage = storage.getTotalUsage(from: hourStart, to: hourEnd)
            
            hourlyUsage[hour] = TokenUsageSummary(
                period: hourInterval,
                totalInputTokens: usage.inputTokens,
                totalOutputTokens: usage.outputTokens,
                totalTokens: usage.totalTokens,
                averageInputTokens: 0,
                averageOutputTokens: 0,
                requestCount: usage.count,
                modelBreakdown: [:]
            )
        }
        
        return hourlyUsage
    }
    
//    func getTopProviders(limit: Int = 10, from startDate: Date? = nil, to endDate: Date? = nil) -> [(provider: String, usage: TokenUsageSummary)] {
//        let records = storage.loadRecords(from: startDate, to: endDate)
//        let groupedByProvider = Dictionary(grouping: records) { $0.Provider }
//        
//        return groupedByProvider
//            .map { provider, userRecords in
//                let totalInput = userRecords.reduce(0) { $0 + $1.inputTokens }
//                let totalOutput = userRecords.reduce(0) { $0 + $1.outputTokens }
//                let total = userRecords.reduce(0) { $0 + $1.totalTokens }
//                
//                let summary = TokenUsageSummary(
//                    period: DateInterval(start: startDate ?? Date.distantPast, end: endDate ?? Date()),
//                    totalInputTokens: totalInput,
//                    totalOutputTokens: totalOutput,
//                    totalTokens: total,
//                    averageInputTokens: Double(totalInput) / Double(userRecords.count),
//                    averageOutputTokens: Double(totalOutput) / Double(userRecords.count),
//                    requestCount: userRecords.count,
//                    modelBreakdown: [:]
//                )
//                
//                return (provider, summary)
//            }
//            .sorted { $0.usage.totalTokens > $1.usage.totalTokens }
//            .prefix(limit)
//            .map { $0 }
//    }
}
