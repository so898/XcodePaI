//
//  UsageSettingSectionView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/10/22.
//

import SwiftUI
import Charts

// Time range enum
enum TimeRange: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "This Week"
    case month = "This Month"
    
    var id: String { self.rawValue }
}

// Main view
struct UsageSettingSectionView: View {
    @State private var selectedTimeRange: TimeRange = .month
    @State private var selectedDate: Date?
    @State private var hoveredBarData: BarChartData?
    
    // Get records by time range
    private var filteredRecords: [TokenUsageRecord] {
        switch selectedTimeRange {
        case .today:
            return RecordTracker.shared.getTodayRecords()
        case .week:
            return RecordTracker.shared.getThisWeekRecords()
        case .month:
            return RecordTracker.shared.getThisMonthRecords()
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Spacer()
                // time selector
                Picker("Time Period", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases) { range in
                        Text(range.rawValue.localizedString).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                Spacer()
            }.padding()
            
            // Overview of data
            StatsOverviewView(records: filteredRecords)
                .padding(.horizontal)
            
            // Chart area
            ScrollView {
                VStack(spacing: 30) {
                    // Code Completion Line Chart
                    CompletionRateLineChart(
                        records: filteredRecords,
                        selectedDate: $selectedDate
                    )
                    .frame(height: 300)
                    
                    // Token Usage Bar Chart
                    TokenUsageBarChart(
                        records: filteredRecords,
                        hoveredBarData: $hoveredBarData
                    )
                    .frame(height: 400)
                }
                .padding()
            }
        }
        .navigationTitle("Token Usage".localizedString)
        .overlay {
            // Info
            if let hoveredData = hoveredBarData {
                BarChartTooltip(data: hoveredData)
            }
        }
    }
}

// Status Overview
struct StatsOverviewView: View {
    let records: [TokenUsageRecord]
    
    private var totalInputTokens: Int {
        records.reduce(0) { $0 + $1.inputTokens }
    }
    
    private var totalOutputTokens: Int {
        records.reduce(0) { $0 + $1.outputTokens }
    }
    
    private var totalTokens: Int {
        records.reduce(0) { $0 + $1.totalTokens }
    }
    
    private var uniqueProviders: Int {
        Set(records.map { $0.provider }).count
    }
    
    private var uniqueModels: Int {
        Set(records.map { $0.modelName }).count
    }
    
    // Completions
    private var completionStats: (total: Int, accepted: Int) {
        let completionRecords = records.filter { $0.isCompletion }
        let total = completionRecords.count
        let accepted = completionRecords.filter { $0.completionAccepted }.count
        return (total, accepted)
    }
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 8) {
            StatCard(title: "Prompt Token".localizedString, value: "\(totalInputTokens)", color: .blue)
            StatCard(title: "Completion Token".localizedString, value: "\(totalOutputTokens)", color: .green)
            StatCard(title: "Total Token".localizedString, value: "\(totalTokens)", color: .orange)
            StatCard(title: "Used Models".localizedString, value: "\(uniqueModels)", color: .purple)
        }
        
        // Code Completion
        HStack(spacing: 8) {
            StatCard(title: "Total Count".localizedString, value: "\(completionStats.total)", color: .indigo)
            StatCard(title: "Acceptance Count".localizedString, value: "\(completionStats.accepted)", color: completionStats.total > 0 ? .green : .gray)
            StatCard(title: "Acceptance Rate".localizedString, value: completionStats.total > 0 ? "\(Int(Double(completionStats.accepted) / Double(completionStats.total) * 100))%" : "0%", color: .purple)
        }
        .padding(.horizontal)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .center) {
            Spacer()
            VStack(alignment: .center, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(4)
        .background(Color.black.opacity(0.25))
        .cornerRadius(12)
    }
}

// Code completion line chart
struct CompletionRateLineChart: View {
    let records: [TokenUsageRecord]
    @Binding var selectedDate: Date?
    
    // Process data
    private var completionData: [CompletionData] {
        let completionRecords = records.filter { $0.isCompletion }
        
        let groupedByDate = Dictionary(grouping: completionRecords) { record in
            Calendar.current.startOfDay(for: record.timestamp)
        }
        
        return groupedByDate.map { date, records in
            let totalCount = records.count
            let acceptedCount = records.filter { $0.completionAccepted }.count
            let acceptanceRate = totalCount > 0 ? Double(acceptedCount) / Double(totalCount) : 0
            
            return CompletionData(
                date: date,
                totalCount: totalCount,
                acceptedCount: acceptedCount,
                acceptanceRate: acceptanceRate
            )
        }.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Code Completion Acceptance Rate")
                .font(.headline)
            
            if completionData.isEmpty {
                HStack(content: {
                    Spacer()
                    Text("No Data")
                        .foregroundColor(.secondary)
                        .frame(height: 300)
                    Spacer()
                })
            } else {
                Chart(completionData) { data in
                    LineMark(
                        x: .value("Date", data.date),
                        y: .value("Rate", data.acceptanceRate)
                    )
                    .foregroundStyle(.blue)
                    .symbol(Circle().strokeBorder(lineWidth: 2))
                    
                    PointMark(
                        x: .value("Date", data.date),
                        y: .value("Rate", data.acceptanceRate)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(60)
                    .opacity(selectedDate == data.date ? 1 : 0)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.day().month())
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let rate = value.as(Double.self) {
                                Text("\(Int(rate * 100))%")
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        if let plotFrame = proxy.plotFrame {
                                            let xPosition = value.location.x - geometry[plotFrame].origin.x
                                            if let date: Date = proxy.value(atX: xPosition) {
                                                selectedDate = date
                                            }
                                        }
                                    }
                                    .onEnded { _ in
                                        selectedDate = nil
                                    }
                            )
                    }
                }
                
                // Display selected info
                if let selectedDate = selectedDate,
                   let data = completionData.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(data.date, format: .dateTime.day().month().year())")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 16) {
                                Text("Total: \(data.totalCount)")
                                Text("Accept: \(data.acceptedCount)")
                                Text("Rate: \(Int(data.acceptanceRate * 100))%")
                            }
                            .font(.caption)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.25))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// Token usage bar chart
struct TokenUsageBarChart: View {
    let records: [TokenUsageRecord]
    @Binding var hoveredBarData: BarChartData?
    
    // Separate via provider and model name
    private var groupedData: [BarChartData] {
        let groupedByProviderAndModel = Dictionary(grouping: records) { record in
            "\(record.provider)%%\(record.modelName)"
        }
        
        return groupedByProviderAndModel.map { key, records in
            let totalInputTokens = records.reduce(0) { $0 + $1.inputTokens }
            let totalOutputTokens = records.reduce(0) { $0 + $1.outputTokens }
            let totalTokens = records.reduce(0) { $0 + $1.totalTokens }
            
            let components = key.split(separator: "%%")
            let provider = String(components[0])
            let modelName = String(components[1])
            
            return BarChartData(
                provider: provider,
                modelName: modelName,
                inputTokens: totalInputTokens,
                outputTokens: totalOutputTokens,
                totalTokens: totalTokens
            )
        }.sorted { $0.totalTokens > $1.totalTokens }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Token Usage Index")
                .font(.headline)
            
            if groupedData.isEmpty {
                HStack(content: {
                    Spacer()
                    Text("No Data")
                        .foregroundColor(.secondary)
                        .frame(height: 300)
                    Spacer()
                })
            } else {
                Chart(groupedData) { data in
                    BarMark(
                        x: .value("Provider", data.provider),
                        y: .value("Token Count", data.totalTokens)
                    )
                    .foregroundStyle(by: .value("Model", data.modelName))
                    .annotation(position: .top) {
                        Text("\(data.totalTokens)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .chartForegroundStyleScale(range: [.blue, .green, .orange, .purple, .pink, .yellow, .cyan, .indigo])
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let provider = value.as(String.self) {
                                Text(provider)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        if let plotFrame = proxy.plotFrame {
                                            let xPosition = value.location.x - geometry[plotFrame].origin.x
                                            let yPosition = value.location.y - geometry[plotFrame].origin.y
                                            
                                            if let provider: String = proxy.value(atX: xPosition),
                                               let totalTokens: Int = proxy.value(atY: yPosition) {
                                                                                                
                                                var dataItems = groupedData.filter { $0.provider == provider }
                                                
                                                if !dataItems.isEmpty {
                                                    dataItems = dataItems.sorted{ $0.totalTokens > $1.totalTokens}
                                                }
                                                
                                                var maxTokens = 0
                                                var maxData: BarChartData?
                                                dataItems.forEach { data in
                                                    maxTokens += data.totalTokens
                                                    if maxData == nil, maxTokens > totalTokens {
                                                        maxData = data
                                                    }
                                                }
                                                hoveredBarData = maxData
                                            }
                                        }
                                    }
                                    .onEnded { _ in
                                        hoveredBarData = nil
                                    }
                            )
                    }
                }
                
                // Chart
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], alignment: .leading, spacing: 8) {
                    ForEach(Array(Set(groupedData.map { $0.modelName })), id: \.self) { model in
                        HStack {
                            Circle()
                                .fill(colorForModel(model))
                                .frame(width: 8, height: 8)
                            Text(model)
                                .font(.caption)
                            Spacer()
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color.black.opacity(0.25))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func colorForModel(_ model: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .yellow, .cyan, .indigo]
        let index = abs(model.hashValue) % colors.count
        return colors[index]
    }
}

// Chart Info
struct BarChartTooltip: View {
    let data: BarChartData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(data.modelName)
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Provider: \(data.provider)")
                    .font(.caption)
                Text("Prompt Token: \(data.inputTokens)")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text("Completion Token: \(data.outputTokens)")
                    .font(.caption)
                    .foregroundColor(.green)
                Text("Total Token: \(data.totalTokens)")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color.black.opacity(0.25))
        .cornerRadius(8)
        .shadow(radius: 5)
        .padding()
        .frame(maxWidth: 200)
    }
}

// Models
struct CompletionData: Identifiable {
    let id = UUID()
    let date: Date
    let totalCount: Int
    let acceptedCount: Int
    let acceptanceRate: Double
}

struct BarChartData: Identifiable {
    let id = UUID()
    let provider: String
    let modelName: String
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
}
