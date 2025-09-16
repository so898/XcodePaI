//
//  ModelAddView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/14.
//

import SwiftUI

struct ModelAddView: View {
    var modelNameBlock: (String) -> Void
    
    @State var name: String = ""
    @State var showAlert = false
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Input New Model Name".localizedString).bold()
            TextField("Model name".localizedString, text: $name)
            HStack(spacing: 8) {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("Cancel".localizedString)
                }
                Button {
                    if name.isEmpty {
                        showAlert = true
                        return
                    }
                    modelNameBlock(name)
                    dismiss()
                } label: {
                    Text("Add".localizedString)
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
        }
        .frame(maxWidth: 300)
        .padding()
        .alert("Model name can not be empty.".localizedString, isPresented: $showAlert) {
        }
    }
}
