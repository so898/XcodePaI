//
//  GeneralSettingSectionView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/11.
//

import SwiftUI

struct GeneralSettingSectionView: View {
    @State private var contentLayout = 0 // 0 for Vertical, 1 for Horizontal
    @State private var showInMenuBar = true
    @State private var toolbarStyle = "Only Icon (Default)"
    @State private var truncationStyle = "Tail"
    @State private var portNumber = "9090"
    @State private var overrideProxyOnLaunch = true
    @State private var startRecordingOnLaunch = true
    
    var body: some View {
        ScrollView {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 18) {
                
                GridRow(alignment: .top) {
                    Text("Content layout:")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("", selection: $contentLayout) {
                            Text("Vertical").tag(0)
                            Text("Horizontal").tag(1)
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                        
                        Text("Dashboard layout.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                
                GridRow {
                    Text("Menubar:")
                    Toggle("Show icon on system menubar", isOn: $showInMenuBar)
                        .toggleStyle(.checkbox)
                }
                
                GridRow(alignment: .center) {
                    Text("Tools :")
                    Picker("", selection: $toolbarStyle) {
                        Text("Only Icon (Default)").tag("Only Icon (Default)")
                        // More options
                    }
                    .frame(maxWidth: 150, alignment: .leading)
                }
                
                GridRow(alignment: .center) {
                    Text("Cut:")
                    Picker("", selection: $truncationStyle) {
                        Text("Tail").tag("Tail")
                        // More options
                    }
                    .frame(maxWidth: 150, alignment: .leading)
                }
                
                GridRow {
                    Divider().gridCellColumns(2).padding(.vertical, 10)
                }
                
                GridRow(alignment: .center) {
                    Text("Port:")
                    TextField("", text: $portNumber)
                        .textFieldStyle(.plain)
                        .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                        .background(Color.black.opacity(0.3))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray))
                        .cornerRadius(5)
                        .frame(width: 80)
                }
                
                GridRow(alignment: .top) {
                    Color.clear// Alignment
                    VStack(alignment: .leading, spacing: 5) {
                        Toggle("Run with system init", isOn: $overrideProxyOnLaunch)
                            .toggleStyle(.checkbox)
                        Text("Override configuration")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                GridRow(alignment: .top) {
                    Color.clear
                    VStack(alignment: .leading, spacing: 5) {
                        Toggle("Record when init", isOn: $startRecordingOnLaunch)
                            .toggleStyle(.checkbox)
                        Text("Record chat & completions")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                
                GridRow {
                    Color.clear
                    Button("High level...") {
                    }
                }
            }
            .gridColumnAlignment(.trailing)
            .padding(30)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}
