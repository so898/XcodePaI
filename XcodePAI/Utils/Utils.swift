//
//  Utils.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/9/6.
//

import Foundation
import ApplicationServices

struct Utils {
    static func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
