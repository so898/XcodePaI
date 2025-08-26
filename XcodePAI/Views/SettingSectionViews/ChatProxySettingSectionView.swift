//
//  ChatProxySettingSectionView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/11.
//

import SwiftUI
import Combine

struct ChatProxySettingSectionView: View {
    @State private var portNumber = "\(Configer.chatProxyPort)"
    @State private var thinkStyle: Int = Configer.chatProxyThinkStyle.rawValue
    @State private var toolUseType: Int = Configer.chatProxyToolUseInRequest ? 0 : 1
    
    var body: some View {
        ScrollView {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 18) {
                
                // --- Chat Proxy Port ---
                GridRow(alignment: .center) {
                    Text("Local Server Port:")
                    HStack(spacing: 10) {
                        TextField("", text: $portNumber)
                            .textFieldStyle(.plain)
                            .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                            .background(Color.black.opacity(0.3))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray))
                            .cornerRadius(5)
                            .frame(width: 80)
                            .onChange(of: portNumber) { _, newValue in
                                guard let value = UInt16(newValue) else {
                                    return
                                }
                                Configer.chatProxyPort = value
                            }
                        Button("Restart Server") {
                            ChatProxy.shared.restart()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
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
                    .onChange(of: thinkStyle, { _, tag in
                        Configer.chatProxyThinkStyle = .init(rawValue: tag)!
                    })
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
                        .onChange(of: toolUseType) { _, tag in
                            Configer.chatProxyToolUseInRequest = (tag == 0)
                        }
                        
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
