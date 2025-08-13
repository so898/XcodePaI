//
//  AppIconView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/13.
//

import SwiftUI

struct AppIconView: View {
    var body: some View {
        if let image = NSImage(named: "AppIcon") {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            EmptyView()
        }
    }
}

// MARK: - Custom Button Style
struct GetButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .padding(.vertical, 6)
            .padding(.horizontal, 16)
            .background(Color.gray.opacity(0.4))
            .foregroundColor(.white)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}