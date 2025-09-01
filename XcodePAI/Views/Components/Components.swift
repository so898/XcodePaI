//
//  Components.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/16.
//

import Foundation
import SwiftUI

// MARK: - From File Components

struct FormFieldRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            content
                .foregroundColor(.primary)
        }
        .padding(16)
    }
}

struct FormDeletableFieldRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content
    var deleteAction: () -> Void
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            content
                .foregroundColor(.primary)
            Button {
                deleteAction()
            } label: {
                Image(systemName: "minus")
                    .frame(width: 20, height: 20)
                    .foregroundColor(.white)
                    .background(Color.red)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }
}

struct FormKVFieldRow<Content: View>: View {
    @ViewBuilder let key: Content
    @ViewBuilder let value: Content
    var deleteAction: () -> Void
    
    var body: some View {
        HStack {
            key
                .foregroundColor(.primary)
            Spacer()
            Text("=")
            Spacer()
            value
                .foregroundColor(.primary)
            Button {
                deleteAction()
            } label: {
                Image(systemName: "minus")
                    .frame(width: 20, height: 20)
                    .foregroundColor(.white)
                    .background(Color.red)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }
}

struct InfoRow: View {
    let label: String
    @Binding var value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
        .padding()
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

// MARK: Hex to SwiftUI Color
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
