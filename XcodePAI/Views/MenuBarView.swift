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
    
    // Menubar icon setup
    func setup() {
        menuItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusBarButton = menuItem?.button {
            let hostingView = NSHostingView(rootView: StatusBarIconView())
            hostingView.frame = NSRect(x: 0, y: 0, width: 22, height: 22)
            
            statusBarButton.addSubview(hostingView)
            statusBarButton.frame = NSRect(x: 0, y: 0, width: 22, height: 22)
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
            item = NSMenuItem(title: "Local Port: 50222", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        item = NSMenuItem(title: "XcodePaI model", action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
        
        menu.addItem(NSMenuItem.separator())
        
        item = NSMenuItem(title: "Config...", action: #selector(openSettingsView), keyEquivalent: ",")
        item.isEnabled = false
        menu.addItem(item)
    }
}

// MARK: Actions
extension MenuBarManager {
    
    @objc private func openSettingsView() {
        
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
