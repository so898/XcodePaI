//
//  AppDelegate.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/12.
//

import Foundation
import Cocoa
import SuggestionBasic
import IPCServer

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
//        NSApp.setActivationPolicy(.accessory)
        
        StorageManager.shared.load()
        
        let _ = MCPRunner.shared
        
        // Menu
        MenuBarManager.shared.setup()
        
        // Chat Proxy
        let _ = ChatProxy.shared
        
        
//        Wormhole.shared.listenMessage(for: "EditContent") { (content: EditorContent, replyHandler: @escaping (Any?) -> Void) in
//            print("sm.pro: \(content)")
//        }
        
        IPCServer.shared
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
