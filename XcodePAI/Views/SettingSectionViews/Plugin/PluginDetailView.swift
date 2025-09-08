//
//  PluginDetailView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/9/9.
//

import SwiftUI

struct PluginDetailView: View {
    @State var plugin: PluginInfo
    let bundle: Bundle?
    let isNew: Bool
    
    var savePlugin: (Bundle) -> Void
    
    var removePlugin: ((String) -> Void)?
    
    // Close Sheet
    @Environment(\.dismiss) var dismiss
    
    init(plugin: PluginInfo, bundle: Bundle?, isNew: Bool = true, savePlugin: @escaping (Bundle) -> Void, removePlugin: ((String) -> Void)? = nil) {
        self.plugin = plugin
        self.bundle = bundle
        self.isNew = isNew
        self.savePlugin = savePlugin
        self.removePlugin = removePlugin
    }
    
    var body: some View {
        ZStack {
            Color(red: 30/255, green: 30/255, blue: 33/255).edgesIgnoringSafeArea(.all)
            
            VStack(alignment: .leading, spacing: 20) {
                headerView
                
                formSection
                
                Spacer()
                
                buttonsSection
            }
            .padding()
        }
    }
    
    // MARK: - subviews
    
    private var headerView: some View {
        HStack(spacing: 15) {
            ZStack {
                Color.black
                Image(systemName: "square.stack.3d.forward.dottedline").font(.system(size: 24)).foregroundColor(.white)
            }
            .cornerRadius(10)
            .frame(width: 64, height: 64)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(plugin.name)
                    .font(.headline)
                    .fontWeight(.bold)
                Text(plugin.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(8)
        .background(Color.black.opacity(0.25))
        .cornerRadius(12)
    }
    
    private var formSection: some View {
        VStack(spacing: 8) {
            VStack(spacing: 0) {
                FormFieldRow(label: "ID".localizedString, content: {
                    Spacer()
                    Text(plugin.id)
                })
                FormFieldRow(label: "Version".localizedString, content: {
                    Spacer()
                    Text(plugin.version)
                })
            }
            .background(Color.black.opacity(0.25))
            .cornerRadius(12)
            
            VStack(spacing: 0) {
                FormFieldRow(label: "Support Chat".localizedString, content: {
                    Spacer()
                    Text(plugin.supportChat ? "True" : "False")
                })
                FormFieldRow(label: "Support Code Suggestion".localizedString, content: {
                    Spacer()
                    Text(plugin.supportCodeSuggestion ? "True" : "False")
                })
            }
            .background(Color.black.opacity(0.25))
            .cornerRadius(12)
        }
    }
    
    private var buttonsSection: some View {
        HStack {
            if !isNew {
                Button(role: .destructive) {
                    if let removePlugin = removePlugin {
                        removePlugin(plugin.id)
                    }
                    dismiss()
                } label: {
                    Text("Delete Plugin")
                        .frame(maxWidth: .infinity)
                }
                .tint(Color.red.opacity(0.7))
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: 200)
            }
            
            Spacer()
            
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            
            if isNew, let bundle {
                Button("Save") {
                    savePlugin(bundle)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
}
