//
//  ChatProxySettingSectionView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/11.
//

import SwiftUI

struct ChatProxySettingSectionView: View {
    @State private var portNumber = "50222"
    
    var body: some View {
        ScrollView {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 18) {
                
                // --- Chat Proxy Port ---
                GridRow(alignment: .center) {
                    Text("Local LLM Server Port:")
                    TextField("", text: $portNumber)
                        .textFieldStyle(.plain)
                        .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                        .background(Color.black.opacity(0.3))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray))
                        .cornerRadius(5)
                        .frame(width: 80)
                }
                
                GridRow {
                    Divider().gridCellColumns(2).padding(.vertical, 10)
                }
                
            }
            .gridColumnAlignment(.trailing)
            .padding(30)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle("Chat Proxy")
    }
}
