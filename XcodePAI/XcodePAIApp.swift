//
//  XcodePAIApp.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/8.
//

import SwiftUI

@main
struct XcodePAIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    init() {
        let _ = ChatProxy.shared
    }
}
