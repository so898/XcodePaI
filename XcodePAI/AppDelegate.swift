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
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let service = Service.shared
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        if let preferredLanguage = UserDefaults.standard.string(forKey: "AppLanguage") {
            Bundle.currentLanguage = preferredLanguage
        }
        
        if !Configer.openConfigurationWhenStartUp {
            NSApp.setActivationPolicy(.accessory)
        }
        
        // Plugin
        _ = PluginManager.shared
        
        // MCP Runner
        _ = MCPRunner.shared
        
        // Menu
        MenuBarManager.shared.setup()
        
        // Chat Proxy
        _ = ChatProxy.shared
        
        // IPC
        _ = IPCServer.shared
        
        // Record Tracker
        _ = RecordTracker.shared
        
        // Update Check
        SUUpdater.shared().checkForUpdatesInBackground()
        
        Task {[weak self] in
            await StorageManager.shared.load()
            
            DispatchQueue.main.async {[weak self] in
                guard let `self` = self else {
                    return
                }
                if Configer.openConfigurationWhenStartUp {
                    MenuBarManager.shared.openSettingsView()
                }
                
                if Utils.checkAccessibilityPermission() {
                    // Has accessibility permission, start server
                    checkAndStartServer()
                } else {
                    // No permission, start timer to check permission
                    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {[weak self] _ in
                        guard let `self` = self else {
                            return
                        }
                        Task {[weak self] in
                            await self?.checkAndStartServer()
                        }
                    }
                }
            }
            
            if Configer.updateModelsWhenStartUp {
                ProviderModelRefresher.shared.refreshAllProviderModels()
            }
        }
    }
    
    private var timer: Timer?
    private var serviceStarted = false
    private let quickController = ChatProxyQuickWindowController()
    
    @MainActor private func checkAndStartServer() {
        guard Utils.checkAccessibilityPermission(), !serviceStarted else {
            return
        }
        timer?.invalidate()
        timer = nil
        
        serviceStarted = true
        
        _ = XcodeInspector.shared
        quickController.setup()
        service.start()
        AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true,
        ] as CFDictionary)
        
        for model in StorageManager.shared.completionConfigs {
            if Configer.completionSelectConfigId == model.id {
                SuggestionPortal.shared.current = model.getSuggestion()
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
