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
        if !Configer.openConfigurationWhenStartUp {
            NSApp.setActivationPolicy(.accessory)
        }
        
        _ = MCPRunner.shared
        
        // Menu
        MenuBarManager.shared.setup()
        
        // Chat Proxy
        _ = ChatProxy.shared
        
        // IPC
        _ = IPCServer.shared
        
        Task {[weak self] in
            await StorageManager.shared.load()
            
            DispatchQueue.main.async {[weak self] in
                if Configer.openConfigurationWhenStartUp {
                    MenuBarManager.shared.openSettingsView()
                }
                
                if Utils.checkAccessibilityPermission() {
                    _ = XcodeInspector.shared
                    self?.service.start()
                    AXIsProcessTrustedWithOptions([
                        kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true,
                    ] as CFDictionary)
                    
                    for model in StorageManager.shared.completionConfigs {
                        if Configer.completionSelectConfigId == model.id {
                            SuggestionPortal.shared.current = model.getSuggestion()
                        }
                    }
                }
            }
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
