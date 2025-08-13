//
//  ModelProviderSettingView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 8/13/25.
//

import SwiftUI
import Combine

// MARK: - Data Models

struct AIModel: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var identifier: String
    var isEnabled: Bool
    var isFavorite: Bool
}

class ModelProviderManager: ObservableObject {
    static let storageKey = "LLMModelProviderStorage"
    
    @Published private(set) var providers: [LLMModelProvider] = []
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadInitialValue()
    }
    
    private func loadInitialValue() {
        LocalStorage.shared.fetch(forKey: Self.storageKey)
            .replaceNil(with: [])
            .assign(to: \.providers, on: self)
            .store(in: &cancellables)
    }
    
    func addModelProvider(_ provider: LLMModelProvider) {
        var currentProviders = providers
        currentProviders.append(provider)
        saveModelProviders(currentProviders)
    }
    
    func updateModelProvider(_ provider: LLMModelProvider) {
        var currentProviders = providers
        if let index = currentProviders.firstIndex(where: { $0.id == provider.id }) {
            currentProviders[index] = provider
            saveModelProviders(currentProviders)
        }
    }
    
    func deleteModelProvider(_ provider: LLMModelProvider) {
        var currentProviders = providers
        if let index = currentProviders.firstIndex(where: { $0.id == provider.id }) {
            currentProviders.remove(at: index)
            saveModelProviders(currentProviders)
        }
    }
    
    private func saveModelProviders(_ providers: [LLMModelProvider]) {
        self.providers = providers
        LocalStorage.shared.save(providers, forKey: Self.storageKey)
            .sink { _ in }
            .store(in: &cancellables)
    }
}

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
                    Button("Add a Model Provider...") {
                        isShowingSheet = true
                    }
                        .padding(.init(top: 0, leading: 0, bottom: 0, trailing: 16))
                }
            }
            .padding(.init(top: 0, leading: 16, bottom: 24, trailing: 16))
        }
        .navigationTitle("Model Provider")
        .sheet(isPresented: $isShowingSheet) {
            ModelProviderEditView(currentProvider: nil){ provider in
                providerManager.addModelProvider(provider)
            }
        }
    }
}


// MARK: - Provider Detail View
struct ModelProviderDetailView: View {
    @ObservedObject var providerManager: ModelProviderManager

    @State private var provider: LLMModelProvider
        
    @State private var models: [AIModel]
    @State private var isProviderEnabled: Bool = true
    @State private var sortOrder = [KeyPathComparator(\AIModel.name)]
    
    @State private var istoggle: Bool
    
    @State private var isShowingSheet = false
    
    @Environment(\.dismiss) private var dismiss

    init(providerManager: ModelProviderManager, provider: LLMModelProvider) {
        self.providerManager = providerManager
        _provider = State(initialValue: provider)
        _models = State(initialValue: [
            AIModel(name: "codeqwen1.5-7b-chat", identifier: "codeqwen1.5-7b-chat", isEnabled: true, isFavorite: false),
            AIModel(name: "deepseek-r1", identifier: "deepseek-r1", isEnabled: true, isFavorite: false),
            AIModel(name: "deepseek-r1-distill-...", identifier: "deepseek-r1-distill-ll...", isEnabled: true, isFavorite: true),
            AIModel(name: "deepseek-r1-distill-...", identifier: "deepseek-r1-distill-ll...", isEnabled: true, isFavorite: false),
            AIModel(name: "deepseek-v3", identifier: "deepseek-v3", isEnabled: true, isFavorite: false),
            AIModel(name: "qvq-max-2025-05-15", identifier: "qvq-max-2025-05-15", isEnabled: true, isFavorite: false),
            AIModel(name: "qvq-plus", identifier: "qvq-plus", isEnabled: false, isFavorite: false),
            AIModel(name: "codeqwen1.5-7b-chat", identifier: "codeqwen1.5-7b-chat", isEnabled: true, isFavorite: false),
            AIModel(name: "deepseek-r1", identifier: "deepseek-r1", isEnabled: true, isFavorite: false),
            AIModel(name: "deepseek-r1-distill-...", identifier: "deepseek-r1-distill-ll...", isEnabled: true, isFavorite: true),
            AIModel(name: "deepseek-r1-distill-...", identifier: "deepseek-r1-distill-ll...", isEnabled: true, isFavorite: false),
            AIModel(name: "deepseek-v3", identifier: "deepseek-v3", isEnabled: true, isFavorite: false),
            AIModel(name: "qvq-max-2025-05-15", identifier: "qvq-max-2025-05-15", isEnabled: true, isFavorite: false),
            AIModel(name: "qvq-plus", identifier: "qvq-plus", isEnabled: false, isFavorite: false),
            AIModel(name: "codeqwen1.5-7b-chat", identifier: "codeqwen1.5-7b-chat", isEnabled: true, isFavorite: false),
            AIModel(name: "deepseek-r1", identifier: "deepseek-r1", isEnabled: true, isFavorite: false),
            AIModel(name: "deepseek-r1-distill-...", identifier: "deepseek-r1-distill-ll...", isEnabled: true, isFavorite: true),
            AIModel(name: "deepseek-r1-distill-...", identifier: "deepseek-r1-distill-ll...", isEnabled: true, isFavorite: false),
            AIModel(name: "deepseek-v3", identifier: "deepseek-v3", isEnabled: true, isFavorite: false),
            AIModel(name: "qvq-max-2025-05-15", identifier: "qvq-max-2025-05-15", isEnabled: true, isFavorite: false),
            AIModel(name: "qvq-plus", identifier: "qvq-plus", isEnabled: false, isFavorite: false),
            AIModel(name: "codeqwen1.5-7b-chat", identifier: "codeqwen1.5-7b-chat", isEnabled: true, isFavorite: false),
            AIModel(name: "deepseek-r1", identifier: "deepseek-r1", isEnabled: true, isFavorite: false),
            AIModel(name: "deepseek-r1-distill-...", identifier: "deepseek-r1-distill-ll...", isEnabled: true, isFavorite: true),
            AIModel(name: "deepseek-r1-distill-...", identifier: "deepseek-r1-distill-ll...", isEnabled: true, isFavorite: false),
            AIModel(name: "deepseek-v3", identifier: "deepseek-v3", isEnabled: true, isFavorite: false),
            AIModel(name: "qvq-max-2025-05-15", identifier: "qvq-max-2025-05-15", isEnabled: true, isFavorite: false),
            AIModel(name: "qvq-plus", identifier: "qvq-plus", isEnabled: false, isFavorite: false),
        ])
        istoggle = true
    }

    var body: some View {
        VStack(spacing: 0) {
            ModelProviderDetailHeader(provider: provider, isEnabled: $isProviderEnabled) {
                isShowingSheet = true
            }
            
            Divider()

            modelsTable
            
            ModelProviderDetailFooterActionsView {
//                isShowingSheet = true
            }
        }
        .navigationTitle(provider.name)
        .sheet(isPresented: $isShowingSheet) {
            ModelProviderEditView(currentProvider: provider){ updatedProvider in
                self.provider = updatedProvider
                providerManager.updateModelProvider(updatedProvider)
            } removeProvider: { removeProvider in
                providerManager.deleteModelProvider(removeProvider)
                dismiss()
            }
        }
    }
    
    private var modelsTable: some View {
        Table(models, sortOrder: $sortOrder) {
            TableColumn("Identifier", value: \.identifier) { model in
                Text(model.identifier)
            }

            TableColumn("Enabled") { model in
                HStack {
                    Spacer()
                    Toggle("", isOn: $istoggle)
                        .labelsHidden()
                        .toggleStyle(.checkbox)
                    Spacer()
                }
            }
            .width(60)
        }
        .tableStyle(.inset)
        .onChange(of: sortOrder) {
            models.sort(using: sortOrder)
        }
    }
}


// MARK: - Reusable Subviews

struct ModelProviderDetailHeader: View {
    @ObservedObject var provider: LLMModelProvider
    @Binding var isEnabled: Bool
    var editProviderAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ModelProviderIconView(provider: provider, size: 40)
            Text(provider.name).font(.title2).fontWeight(.medium)
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "arrow.trianglehead.clockwise")
                    .frame(width: 10, height: 10)
            }
            .buttonStyle(GetButtonStyle())
            
            Button(action: {
                editProviderAction()
            }) {
                Image(systemName: "pencil")
                    .frame(width: 10, height: 10)
            }
            .buttonStyle(GetButtonStyle())
            
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding()
    }
}

struct ModelProviderDetailFooterActionsView: View {
    var addButtonAction: (() -> Void)
    
    var body: some View {
        HStack {
            Button(action: {
                addButtonAction()
            }) {
                Image(systemName: "plus")
                    .frame(width: 20, height: 20)
            }
            Spacer()
        }
        .padding(8)
        .buttonStyle(.borderless) // Use borderless for icon-only buttons
        .background(Color(nsColor: .controlBackgroundColor))
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
                    Link("About Supported Model Provider...", destination: URL(string: "https://www.apple.com")!).font(.subheadline).padding(.top, 4)
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
//            if let status = provider.status {
                Text("Enabled")
                    .foregroundColor(.secondary)
//            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }
}

