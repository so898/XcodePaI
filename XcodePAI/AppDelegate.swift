//
//  AppDelegate.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/12.
//

import Foundation
import Cocoa
import ApplicationServices
import SuggestionBasic
import IPCServer
import XcodeInspector
import Service
import SuggestionPortal

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let service = Service.shared
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        NSApp.setActivationPolicy(.accessory)
        
        StorageManager.shared.load()
        
        _ = MCPRunner.shared
        
        // Menu
        MenuBarManager.shared.setup()
        
        // Chat Proxy
        _ = ChatProxy.shared
        
        // IPC
        _ = IPCServer.shared
        
        if checkAccessibilityPermission() {
            _ = XcodeInspector.shared
            service.start()
            AXIsProcessTrustedWithOptions([
                kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true,
            ] as CFDictionary)
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
