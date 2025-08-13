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
            .overlay(loadingOverlay)
    }
    
    private var loadingOverlay: some View {
        Group {
            if state.isPresented {
                ZStack {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                    
                    // Loading
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                            .scaleEffect(1.5)
                        
                        if !state.text.isEmpty {
                            Text(state.text)
                                .foregroundColor(.primary)
                                .font(.headline)
                        }
                    }
                    .padding(30)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 5)
                    )
                }
                .zIndex(999) // On the top
                .transition(.opacity)
            }
        }
    }
}

extension View {
    func globalLoading() -> some View {
        modifier(LoadingModifier())
    }
}
