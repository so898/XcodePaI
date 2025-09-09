//
//  PluginSettingSectionView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/9/9.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Model List View
struct PluginSettingSectionView: View {
    @State private var pluginInfos: [PluginInfo]
    @State private var isShowingSheet = false
    
    @State private var showImporter = false
    @State private var selectedUrl: URL?
    @State private var selectedBundle: Bundle?
    @State private var selectedPluginInfo: PluginInfo?
    @State private var shownPluginInfo: PluginInfo?
    
    init() {
        self.pluginInfos = PluginManager.shared.getAllPluginInfos()
    }
    
    var body: some View {
        ScrollView {
            VStack {
                Form {
                    PluginInfoSection()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    
                    Section {
                        ForEach(pluginInfos) { info in
                            PluginInfoRow(info: info)
                                .onTapGesture {
                                    selectedPluginInfo = info
                                    isShowingSheet = true
                                }
                        }
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                
                HStack {
                    Spacer()
                    Button("Add plugin...") {
                        showImporter = true
                    }
                    .controlSize(.large)
                    .padding(.init(top: 0, leading: 0, bottom: 0, trailing: 16))
                }
            }
            .padding(.init(top: 0, leading: 16, bottom: 24, trailing: 16))
        }
        .navigationTitle("Plugin")
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType(filenameExtension: PluginManager.pluginExtension) ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                selectedUrl = urls.first
                if let (bundle, info) = PluginManager.loadPlugin(urls.first) {
                    selectedBundle = bundle
                    selectedPluginInfo = info
                    isShowingSheet = true
                }
            case .failure(let error):
                print("Error: \(error.localizedDescription)")
            }
        }
        .sheet(isPresented: $isShowingSheet) {
            if let selectedPluginInfo {
                PluginDetailView(plugin: selectedPluginInfo, bundle: selectedBundle, savePlugin: { bundle in
                    if let selectedUrl {
                        PluginManager.shared.addPlugin(from: selectedUrl)
                    }
                })
            }
        }
        .sheet(item: $shownPluginInfo) { info in
            PluginDetailView(plugin: info, removePlugin:  { id in
                PluginManager.shared.removePlugin(for: id)
            })
        }
    }
}

struct PluginInfoSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: "333333"), .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "batteryblock.stack.fill").font(.system(size: 24)).foregroundColor(.white)
                }
                .frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Plugin").font(.headline)
                    Text("By adding plugins to enhance ChatProxy and code sugestion capabilities, and by modifying parameters to provide more information, the results become more accurate.").font(.subheadline).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    Link("About plugin...", destination: URL(string: "https://modelcontextprotocol.io/")!).font(.subheadline).padding(.top, 4)
                }
            }
        }
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct PluginInfoRow: View {
    @ObservedObject var info: PluginInfo
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 24 * 0.2, style: .continuous)
                    .fill(Color.blue.opacity(0.7))
                Image(systemName: "batteryblock.fill")
                    .resizable()
                    .renderingMode(.template)
                    .padding(4)
            }
            .frame(width: 24, height: 24)
            Text(info.name)
            Spacer()
            Text(info.description)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }
}
