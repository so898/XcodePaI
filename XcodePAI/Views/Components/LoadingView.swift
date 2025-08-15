//
//  LoadingView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/14.
//

import SwiftUI

final class LoadingState: ObservableObject {
    @Published var isPresented = false
    private(set) var text: String = ""
    
    static let shared = LoadingState()
    private init() {}
    
    func show(text: String = "") {
        self.text = text
        withAnimation(.spring()) {
            isPresented = true
        }
    }
    
    func hide() {
        withAnimation(.easeOut(duration: 0.2)) {
            isPresented = false
        }
    }
}

struct LoadingModifier: ViewModifier {
    @ObservedObject private var state = LoadingState.shared
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: toggleBinding(), content: {
                loadingOverlay
            })
//            .overlay()
    }
    
    private func toggleBinding() -> Binding<Bool> {
        Binding<Bool>(
            get: { state.isPresented },
            set: { newValue in
                state.isPresented = newValue
            }
        )
    }
    
    private var loadingOverlay: some View {
        Group {
            ZStack {
                // Loading
                HStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                    
                    if !state.text.isEmpty {
                        Text(state.text)
                            .foregroundColor(.primary)
                            .font(.headline)
                    }
                }
                .padding(30)
            }
            .zIndex(999) // On the top
            .transition(.opacity)
        }
    }
}

extension View {
    func globalLoading() -> some View {
        modifier(LoadingModifier())
    }
}
