//
//  MenuBarView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/12.
//

import SwiftUI
import AppKit
import WorkspaceSuggestionService
import SuggestionPortal
import XcodeInspector

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
        
        if let defaultConfig = StorageManager.shared.defaultConfig() {
            item = NSMenuItem(title: "ChatProxy".localizedString, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            
            // Port display
            item = NSMenuItem(title: "Local Port: \(Configer.chatProxyPort)".localizedString, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            
            item = NSMenuItem(title: "Model".localizedString, action: nil, keyEquivalent: "")
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
            
            if !StorageManager.shared.mcps.isEmpty {
                item = NSMenuItem(title: "MCP".localizedString, action: nil, keyEquivalent: "")
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
        }
        
        if Utils.checkAccessibilityPermission(){
            menu.addItem(NSMenuItem.separator())
            
            item = NSMenuItem(title: "Completions".localizedString, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            
            let completionEnabled = UserDefaults.shared.value(for: \.realtimeSuggestionToggle)
            item = NSMenuItem(title: "Realtime Suggestion".localizedString, action: #selector(toggleCodeCompletion(item:)), keyEquivalent: "")
            item.isEnabled = true
            item.target = self
            if completionEnabled {
                item.state = .on
            } else {
                item.state = .off
            }
            menu.addItem(item)
            
            var subMenu = NSMenu()
            
            if !StorageManager.shared.completionConfigs.isEmpty {
                item = NSMenuItem(title: "Config".localizedString, action: nil, keyEquivalent: "")
                item.isEnabled = true
                menu.addItem(item)
                
                subMenu = NSMenu()
                var idx = 0
                for config in StorageManager.shared.completionConfigs {
                    let item = NSMenuItem(title: config.name, action: #selector(updateCompletionModelWith(modelItem:)), keyEquivalent: "")
                    item.isEnabled = true
                    item.target = self
                    item.tag = idx
                    if Configer.completionSelectConfigId == config.id {
                        item.state = .on
                    } else {
                        item.state = .off
                    }
                    subMenu.addItem(item)
                    idx += 1
                }
                item.submenu = subMenu
            }
            
            if let lang = DisabledLanguageList.shared.activeDocumentLanguage {
                item = NSMenuItem(title: String(format: "%@ Completions for %@".localizedString, (DisabledLanguageList.shared.isEnabled(lang) ? "Disable".localizedString : "Enable".localizedString), (lang.rawValue)), action: #selector(toggleIgnoreLanguageEnabled), keyEquivalent: "")
                item.isEnabled = true
                item.target = self
                menu.addItem(item)
            } else {
                item = NSMenuItem(title: "No Active Document".localizedString, action: nil, keyEquivalent: "")
                item.isEnabled = false
                item.target = nil
                menu.addItem(item)
            }
        }
        
        if !PluginManager.shared.getAllPlugins().isEmpty {
            menu.addItem(NSMenuItem.separator())
            
            item = NSMenuItem(title: "Plugin".localizedString, action: nil, keyEquivalent: "")
            item.isEnabled = true
            menu.addItem(item)
            
            let subMenu = NSMenu()
            
            var idx = 0
            for pluginInfo in PluginManager.shared.getAllPluginInfos() {
                let item = NSMenuItem(title: pluginInfo.name, action: #selector(updateSelectedPluginWith(modelItem:)), keyEquivalent: "")
                item.isEnabled = true
                item.target = self
                item.tag = idx
                if Configer.selectedPluginId == pluginInfo.id {
                    item.state = .on
                } else {
                    item.state = .off
                }
                subMenu.addItem(item)
                idx += 1
            }
            item.submenu = subMenu
        }
        
        if Configer.showXcodeInstpectorDebug, Utils.checkAccessibilityPermission() {
            
            menu.addItem(NSMenuItem.separator())
            
            item = NSMenuItem(title: "Xcode Inspector Debug".localizedString, action: nil, keyEquivalent: "")
            item.isEnabled = true
            menu.addItem(item)
            
            let subMenu = NSMenu()
            item.submenu = subMenu
            
            let inspector = XcodeInspector.shared
            
            item = NSMenuItem(title: "Active Project: \(inspector.activeProjectRootURL?.path ?? "N/A")".localizedString, action: nil, keyEquivalent: "")
            item.isEnabled = false
            subMenu.addItem(item)
            
            item = NSMenuItem(title: "Active Workspace: \(inspector.activeWorkspaceURL?.path ?? "N/A")".localizedString, action: nil, keyEquivalent: "")
            item.isEnabled = false
            subMenu.addItem(item)
            
            item = NSMenuItem(title: "Active Document: \(inspector.activeDocumentURL?.path ?? "N/A")".localizedString, action: nil, keyEquivalent: "")
            item.isEnabled = false
            subMenu.addItem(item)
            
            if let focusedWindow = inspector.focusedWindow {
                item = NSMenuItem(title: "Active Window: \(focusedWindow.uiElement.identifier)".localizedString, action: nil, keyEquivalent: "")
                item.isEnabled = false
                subMenu.addItem(item)
            } else {
                item = NSMenuItem(title: "Active Window: N/A".localizedString, action: nil, keyEquivalent: "")
                item.isEnabled = false
                subMenu.addItem(item)
            }
            
            if let focusedElement = inspector.focusedElement {
                item = NSMenuItem(title: "Focused Element: \(focusedElement.description)".localizedString, action: nil, keyEquivalent: "")
                item.isEnabled = false
                subMenu.addItem(item)
            } else {
                item = NSMenuItem(title: "Focused Element: N/A".localizedString, action: nil, keyEquivalent: "")
                item.isEnabled = false
                subMenu.addItem(item)
            }
            
            if let sourceEditor = inspector.focusedEditor {
                let label = sourceEditor.element.description
                item = NSMenuItem(title: "Active Source Editor: \(label.isEmpty ? "Unknown" : label)".localizedString, action: nil, keyEquivalent: "")
                item.isEnabled = false
                subMenu.addItem(item)
            } else {
                item = NSMenuItem(title: "Active Source Editor: N/A".localizedString, action: nil, keyEquivalent: "")
                item.isEnabled = false
                subMenu.addItem(item)
            }
            
            menu.items.append(.separator())
            
            for xcode in inspector.xcodes {
                var item = NSMenuItem(
                    title: "Xcode \(xcode.processIdentifier)",
                    action: nil,
                    keyEquivalent: ""
                )
                subMenu.addItem(item)
                let xcodeMenu = NSMenu()
                item.submenu = xcodeMenu
                
                item = NSMenuItem(title: "Is Active: \(xcode.isActive)".localizedString, action: nil, keyEquivalent: "")
                item.isEnabled = false
                xcodeMenu.addItem(item)
                
                item = NSMenuItem(title: "Active Project: \(inspector.activeProjectRootURL?.path ?? "N/A")".localizedString, action: nil, keyEquivalent: "")
                item.isEnabled = false
                xcodeMenu.addItem(item)
                
                item = NSMenuItem(title: "Active Workspace: \(inspector.activeWorkspaceURL?.path ?? "N/A")".localizedString, action: nil, keyEquivalent: "")
                item.isEnabled = false
                xcodeMenu.addItem(item)
                
                item = NSMenuItem(title: "Active Document: \(inspector.activeDocumentURL?.path ?? "N/A")".localizedString, action: nil, keyEquivalent: "")
                item.isEnabled = false
                xcodeMenu.addItem(item)
                
                for (key, workspace) in xcode.realtimeWorkspaces {
                    let workspaceItem = NSMenuItem(
                        title: "Workspace \(key)".localizedString,
                        action: nil,
                        keyEquivalent: ""
                    )
                    xcodeMenu.items.append(workspaceItem)
                    let workspaceMenu = NSMenu()
                    workspaceItem.submenu = workspaceMenu
                    let tabsItem = NSMenuItem(
                        title: "Tabs".localizedString,
                        action: nil,
                        keyEquivalent: ""
                    )
                    workspaceMenu.addItem(tabsItem)
                    let tabsMenu = NSMenu()
                    tabsItem.submenu = tabsMenu
                    for tab in workspace.tabs {
                        item = NSMenuItem(title: tab, action: nil, keyEquivalent: "")
                        item.isEnabled = false
                        tabsMenu.addItem(item)
                    }
                }
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        item = NSMenuItem(title: "Settings…".localizedString, action: #selector(openSettingsView), keyEquivalent: ",")
        item.target = self
        menu.addItem(item)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Exit".localizedString, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }
}

// MARK: Actions
extension MenuBarManager {
    
    @objc private func updateDefaultWith(modelItem: NSMenuItem) {
        if let config = StorageManager.shared.defaultConfig() {
            let model = StorageManager.shared.models[modelItem.tag]
            config.modelName = model.id
            config.modelProvider = model.provider
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
    
    @objc private func toggleCodeCompletion(item: NSMenuItem) {
        let value = UserDefaults.shared.value(for: \.realtimeSuggestionToggle)
        UserDefaults.shared.set(!value, for: \.realtimeSuggestionToggle)
    }
    
    @MainActor @objc private func updateCompletionModelWith(modelItem: NSMenuItem) {
        let model = StorageManager.shared.completionConfigs[modelItem.tag]
        Configer.completionSelectConfigId = model.id
        SuggestionPortal.shared.current = model.getSuggestion()
    }
    
    @objc func toggleIgnoreLanguageEnabled() {
        guard let lang = DisabledLanguageList.shared.activeDocumentLanguage else { return }
        
        if DisabledLanguageList.shared.isEnabled(lang) {
            DisabledLanguageList.shared.disable(lang)
        } else {
            DisabledLanguageList.shared.enable(lang)
        }
    }
    
    @MainActor @objc private func updateSelectedPluginWith(modelItem: NSMenuItem) {
        let info = PluginManager.shared.getAllPluginInfos()[modelItem.tag]
        if Configer.selectedPluginId == info.id {
            Configer.selectedPluginId = nil
        } else {
            Configer.selectedPluginId = info.id
        }
        PluginManager.shared.updateSelectePlugin(id: Configer.selectedPluginId)
    }
    
    @objc public func openSettingsView() {
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
