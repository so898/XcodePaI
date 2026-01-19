//
//  HTTPClientExtension.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2026/1/20.
//

import Foundation

// MARK: - URLRequest Headers Extension
extension URLRequest {
    mutating func addHeaders(_ headers: [String: Any]?) {
        headers?.forEach { key, value in
            switch value {
            case let str as String:
                addValue(str, forHTTPHeaderField: key)
            case let int as Int:
                addValue(String(int), forHTTPHeaderField: key)
            case let double as Double:
                addValue(String(double), forHTTPHeaderField: key)
            default:
                break
            }
        }
    }
}
