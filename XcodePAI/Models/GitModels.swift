//
//  GitModels.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/12/23.
//

import Foundation
import SwiftUI

// MARK: - Models
struct GitFile: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let changeType: GitChangeType
    let isStaged: Bool
}

enum GitChangeType {
    case modified
    case added
    case deleted
    case renamed
    case copied
    case untracked
    
    static func from(status: String) -> GitChangeType {
        switch status {
        case "M": return .modified
        case "A": return .added
        case "D": return .deleted
        case "R": return .renamed
        case "C": return .copied
        case "??": return .untracked
        default: return .modified
        }
    }
    
    var icon: String {
        switch self {
        case .modified: return "M"
        case .added: return "A"
        case .deleted: return "D"
        case .renamed: return "R"
        case .copied: return "C"
        case .untracked: return "U"
        }
    }
    
    var color: Color {
        switch self {
        case .modified: return .blue
        case .added: return .green
        case .deleted: return .red
        case .renamed: return .purple
        case .copied: return .orange
        case .untracked: return Color(nsColor: .darkGray)
        }
    }
}

struct DiffHunk: Identifiable {
    let id = UUID()
    let header: String
    let lines: [DiffLine]
    let file: GitFile
}

struct DiffLine: Identifiable {
    let id = UUID()
    let oldLineNum: Int?
    let newLineNum: Int?
    let content: String
    let type: DiffLineType
}

enum DiffLineType {
    case addition
    case deletion
    case context
}
