//
//  MenuBarView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/12.
//

import SwiftUI
import AppKit

class MenuBarManager: NSObject, ObservableObject {
    
    static let shared = MenuBarManager()
    
    private var menuItem: NSStatusItem?
    private var settingsWindowController: NSWindowController?
    
    // Menubar icon setup
    func setup() {
        menuItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusBarButton = menuItem?.button {
            let hostingView = NSHostingView(rootView: StatusBarIconView())
            hostingView.frame = NSRect(x: 0, y: 0, width: 32, height: 22)
            
            statusBarButton.addSubview(hostingView)
            statusBarButton.frame = NSRect(x: 0, y: 0, width: 32, height: 22)
        }
        
        let menu = NSMenu()
        menu.delegate = self
        menuItem?.menu = menu
    }
    
}

// MARK: NSMenuDelegate
extension MenuBarManager: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        var item: NSMenuItem
        
        if (true) {
            // Port display
            item = NSMenuItem(title: "Local Port: \(Configer.chatProxyPort)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        if let defaultConfig = StorageManager.shared.defaultConfig() {
            item = NSMenuItem(title: "XcodePaI Config", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            
            item = NSMenuItem(title: "Model", action: nil, keyEquivalent: "")
            item.isEnabled = true
            menu.addItem(item)
            
            var subMenu = NSMenu()
            var lastProviderName: String?
            var idx = 0
            for model in StorageManager.shared.models {
                if lastProviderName != model.provider {
                    if lastProviderName != nil {
                        subMenu.addItem(NSMenuItem.separator())
                    }
                    let item = NSMenuItem(title: model.provider, action: nil, keyEquivalent: "")
                    item.isEnabled = false
                    subMenu.addItem(item)
                    lastProviderName = model.provider
                }
                
                let item = NSMenuItem(title: model.id, action: #selector(updateDefaultWith(modelItem:)), keyEquivalent: "")
                item.isEnabled = true
                item.target = self
                item.tag = idx
                if model.id == defaultConfig.modelName {
                    item.state = .on
                } else {
                    item.state = .off
                }
                subMenu.addItem(item)
                idx += 1
            }
            item.submenu = subMenu
            
            item = NSMenuItem(title: "MCP", action: nil, keyEquivalent: "")
            item.isEnabled = true
            menu.addItem(item)
            
            subMenu = NSMenu()
            idx = 0
            for mcp in StorageManager.shared.mcps {
                let item = NSMenuItem(title: mcp.name, action: #selector(updateDefaultWith(mcpItem:)), keyEquivalent: "")
                item.isEnabled = true
                item.target = self
                item.tag = idx
                if defaultConfig.mcps.contains(mcp.name) {
                    item.state = .on
                } else {
                    item.state = .off
                }
                subMenu.addItem(item)
                idx += 1
            }
            item.submenu = subMenu
        }
        
        
        menu.addItem(NSMenuItem.separator())
        
        item = NSMenuItem(title: "Config...", action: #selector(openSettingsView), keyEquivalent: ",")
        item.target = self
        menu.addItem(item)
        
        menu.addItem(NSMenuItem.separator())
                
        menu.addItem(NSMenuItem(title: "Exit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }
}

// MARK: Actions
extension MenuBarManager {
    
    @objc private func updateDefaultWith(modelItem: NSMenuItem) {
        if let config = StorageManager.shared.defaultConfig() {
            let model = StorageManager.shared.models[modelItem.tag]
            config.modelName = model.id
            StorageManager.shared.updateDefaultConfig(config)
        }
    }
    
    @objc private func updateDefaultWith(mcpItem: NSMenuItem) {
        if let config = StorageManager.shared.defaultConfig() {
            let mcp = StorageManager.shared.mcps[mcpItem.tag]
            if config.mcps.contains(mcp.name) {
                config.mcps.removeAll { name in
                    name == mcp.name
                }
            } else {
                config.mcps.append(mcp.name)
            }
            StorageManager.shared.updateDefaultConfig(config)
        }
    }
    
    @objc private func openSettingsView() {
        if let windowController = settingsWindowController, windowController.window?.isVisible == true {
            windowController.window?.close()
            return
        }
        
        if settingsWindowController == nil {
            let settingsView = SettingsView().globalLoading()
            let hostingController = NSHostingController(rootView: settingsView)
            
            let window = SettingsWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false)
            
            window.level = .floating
            window.minSize = NSSize(width: 800, height: 600)
            window.toolbarStyle = .unified
            window.isReleasedWhenClosed = false
            window.contentViewController = hostingController
            window.delegate = self
            
            let wc = NSWindowController(window: window)
            self.settingsWindowController = wc
        }
        
        NSApp.setActivationPolicy(.regular)

        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.center()
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension MenuBarManager: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

// icon
struct StatusBarIconView: View {
    var body: some View {
        HStack {
            Image(systemName: "hammer.fill")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .padding(.init(top: 2, leading: 2, bottom: 2, trailing: 2))
        }
        .frame(width: 22, height: 22)
    }
}
