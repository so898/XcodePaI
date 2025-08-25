//
//  ChatProxySettingSectionView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/11.
//

import SwiftUI

struct ChatProxySettingSectionView: View {
    @State private var portNumber = "50222"
    @State private var thinkStyle = 0
    @State private var toolUseType = 0
    
    var body: some View {
        ScrollView {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 18) {
                
                // --- Chat Proxy Port ---
                GridRow(alignment: .center) {
                    Text("Local Server Port:")
                    TextField("", text: $portNumber)
                        .textFieldStyle(.plain)
                        .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                        .background(Color.black.opacity(0.3))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray))
                        .cornerRadius(5)
                        .frame(width: 80)
                }
                
                GridRow {
                    Divider().gridCellColumns(2)
                }
                
                GridRow(alignment: .center) {
                    Text("Show Think In:")
                    Picker("", selection: $thinkStyle) {
                        Text("Code Snippet (Default)").tag(0)
                        Text("Text with EOT Mark").tag(1)
                        Text("In Reasoning (Not Display)").tag(2)
                    }
                    .frame(maxWidth: 250, alignment: .leading)
                }
                
                GridRow(alignment: .top) {
                    Text("Tool Use:")
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("", selection: $toolUseType) {
                            Text("In Reqeust").tag(0)
                            Text("In System Prompt").tag(1)
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                        
                        Text("Some provider support use tool with request parameters.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                
            }
            .gridColumnAlignment(.trailing)
            .padding(30)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle("Chat Proxy")
    }
}
