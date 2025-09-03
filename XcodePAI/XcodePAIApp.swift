//
//  XcodePAIApp.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/8.
//

import SwiftUI

@main
struct XcodePAIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
         WindowGroup {
             VStack {
                 SettingsView()
                     .globalLoading()
             }
         }
    }
}
