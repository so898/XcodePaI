//
//  ModelProviderSettingView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 8/13/25.
//

import SwiftUI

struct ModelProviderSettingSectionView: View {
    @StateObject private var providerManager = ModelProviderManager()

    var body: some View {
        NavigationStack {
            // Group View for navigaion change
            Group {
                ModelProviderListView(providerManager: providerManager)
            }
            .navigationDestination(for: LLMModelProvider.self) { provider in
                ModelProviderDetailView(providerManager: providerManager, provider: provider)
            }
        }
    }
}

// MARK: - Model List View
struct ModelProviderListView: View {
    @ObservedObject var providerManager: ModelProviderManager
    @State private var isShowingSheet = false
    
    var body: some View {
        ScrollView {
            VStack {
                Form {
                    ModelProviderInfoSection()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)

                    Section {
                        ForEach(providerManager.providers) { provider in
                            NavigationLink(value: provider) {
                                ModelProviderRow(provider: provider)
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                
                HStack {
                    Spacer()
                    Button("Add Model Provider…") {
                        isShowingSheet = true
                    }
                    .controlSize(.large)
                    .padding(.init(top: 0, leading: 0, bottom: 0, trailing: 16))
                }
            }
            .padding(.init(top: 0, leading: 16, bottom: 24, trailing: 16))
        }
        .navigationTitle("Model Provider".localizedString)
        .sheet(isPresented: $isShowingSheet) {
            ModelProviderEditView(currentProvider: nil){ provider in
                providerManager.addModelProvider(provider)
            }
        }
    }
}

struct ModelProviderIconView: View {
    @ObservedObject var provider: LLMModelProvider
    let size: CGFloat
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                .fill(Color.blue.opacity(0.7))
            Image(provider.iconName)
                .resizable()
                .renderingMode(.template)
                .padding(4)
        }
        .frame(width: size, height: size)
    }
}

struct ModelProviderInfoSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "sparkles.square.filled.on.square").font(.system(size: 32)).foregroundColor(.white)
                }
                .frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 4) {
                    Text("LLM Model Provider").font(.headline)
                    Text("Supercharge your Xcode experience with your choice of third-party model. Third-party models will have access to your project files and code.").font(.subheadline).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
//                    Link("About Supported Model Provider...", destination: URL(string: "https://www.apple.com")!).font(.subheadline).padding(.top, 4)
                }
            }
        }
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct ModelProviderRow: View {
    @ObservedObject var provider: LLMModelProvider

    var body: some View {
        HStack(spacing: 12) {
            ModelProviderIconView(provider: provider, size: 24)
            Text(provider.name)
            Spacer()
            Text(provider.enabled ? "Enabled" : "Disabled")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }
}

