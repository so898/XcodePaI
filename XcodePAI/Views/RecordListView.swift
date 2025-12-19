//
//  RecordWindow.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/12/19.
//

import SwiftUI

@MainActor
final class RecordViewModel: ObservableObject {
    @Published var records: [TokenUsageRecord] = []
    @Published var selectedPeriod: TimeRange = .today
    @Published var selectedProvider: String?
    @Published var selectedModelName: String?
    @Published var unfoldRecordId: Int64?
    
    private let tracker = RecordTracker.shared
    
    enum TimeRange: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
    }
    
    init() {
        refresh()
    }
    
    func refresh() {
        let baseRecords: [TokenUsageRecord]
        
        switch selectedPeriod {
        case .today:
            baseRecords = tracker.getTodayRecords()
        case .week:
            baseRecords = tracker.getThisWeekRecords()
        case .month:
            baseRecords = tracker.getThisMonthRecords()
        }
        
        let filteredByProvider = selectedProvider.flatMap { provider in
            baseRecords.filter { $0.provider == provider }
        } ?? baseRecords
        
        let filteredByModelName = selectedModelName.flatMap { modelName in
            filteredByProvider.filter { $0.modelName == modelName }
        } ?? filteredByProvider
        
        self.records = filteredByModelName
        self.unfoldRecordId = nil
    }
    
    var providers: [String] {
        Array(Set(tracker.getThisMonthRecords().map(\.provider))).sorted()
    }
    
    var modelNames: [String] {
        Array(Set(tracker.getThisMonthRecords().map(\.modelName))).sorted()
    }
}

struct RecordListView: View {
    static weak var currentWindow: NSWindow?
    
    @StateObject private var viewModel = RecordViewModel()
    
    var body: some View {
        VStack {
            HStack {
                Picker("Period", selection: $viewModel.selectedPeriod) {
                    ForEach(RecordViewModel.TimeRange.allCases, id: \.rawValue) { range in
                        Text(LocalizedStringKey(range.rawValue)).tag(range)
                    }
                }
                .onChange(of: viewModel.selectedPeriod) {
                    viewModel.refresh()
                }
                
                Picker("Provider", selection: $viewModel.selectedProvider) {
                    Text("All Providers").tag(nil as String?)
                    ForEach(viewModel.providers, id: \.self) { provider in
                        Text(provider).tag(Optional(provider))
                    }
                }
                .onChange(of: viewModel.selectedProvider) {
                    viewModel.refresh()
                }
                
                Picker("Model Name", selection: $viewModel.selectedModelName) {
                    Text("All Models").tag(nil as String?)
                    ForEach(viewModel.modelNames, id: \.self) { model in
                        Text(model).tag(Optional(model))
                    }
                }
                .onChange(of: viewModel.selectedModelName) {
                    viewModel.refresh()
                }
                
                Spacer()
            }
            .padding()
            
            List(viewModel.records, id: \.id) { record in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Timestamp: \(record.timestamp.formatted(date: .complete, time: .standard))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Provider: \(record.provider)")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("Model: \(record.modelName)")
                    }
                    
                    HStack {
                        Text("Input Tokens: \(record.inputTokens)")
                        Text("Output Tokens: \(record.outputTokens)")
                        Text("Total: \(record.totalTokens)")
                    }
                    
                    if record.isCompletion {
                        HStack {
                            Text("Completion Accepted: \(record.completionAccepted ? "Yes" : "No")")
                                .foregroundColor(record.completionAccepted ? .green : .red)
                        }
                    }
                    
                    if let metadata = record.getMetadata() {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Spacer()
                                Button() {
                                    if viewModel.unfoldRecordId == record.id {
                                        viewModel.unfoldRecordId = nil
                                    } else {
                                        viewModel.unfoldRecordId = record.id
                                    }
                                } label: {
                                    if viewModel.unfoldRecordId == record.id {
                                        Image(systemName: "arrowtriangle.up.fill")
                                    } else {
                                        Image(systemName: "arrowtriangle.down.fill")
                                    }
                                }
                            }
                            .padding(.init(top: 20, leading: 0, bottom: 0, trailing: 30))
                            
                            if viewModel.unfoldRecordId == record.id {
                                HStack {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .fill(Color.gray.opacity(0.1))
                                        Text("Metadata: \(String(describing: metadata))")
                                            .textSelection(.enabled)
                                            .font(.footnote)
                                            .foregroundColor(.gray)
                                            .padding(.init(top: 5, leading: 5, bottom: 5, trailing: 5))
                                    }
                                }
                                .padding(.init(top: 0, leading: 5, bottom: 0, trailing: 5))
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Token Usage Records")
    }
}
