//
//  MenuBarView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/12.
//

import SwiftUI
import AppKit

class MenuBarManager: NSObject, ObservableObject, NSPopoverDelegate {
    
    static let shared = MenuBarManager()
    
    private var menuItem: NSStatusItem?
    private var popover: NSPopover?
    
    // Menubar icon setup
    func setup() {
        menuItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusBarButton = menuItem?.button {
            let hostingView = NSHostingView(rootView: StatusBarIconView())
            hostingView.frame = NSRect(x: 0, y: 0, width: 44, height: 22)
            
            // Add click action
            let gesture = NSClickGestureRecognizer(target: self, action: #selector(togglePopover))
            statusBarButton.addGestureRecognizer(gesture)
            
            statusBarButton.addSubview(hostingView)
        }
        
        configurePopover()
    }
    
    // show popover
    private func configurePopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 200, height: 200)
        popover?.behavior = .transient
        popover?.delegate = self
        popover?.contentViewController = NSHostingController(
            rootView: PopoverContentView().padding()
        )
    }
    
    // show alert
    @objc func togglePopover() {
        guard let menuItem = menuItem, let popover = popover else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(
                relativeTo: menuItem.button!.bounds,
                of: menuItem.button!,
                preferredEdge: .maxY
            )
        }
    }
    
    // tap outside close alert
    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        true
    }
}

// icon
struct StatusBarIconView: View {
    var body: some View {
        Image(systemName: "power")
            .resizable()
            .scaledToFit()
            .frame(width: 22, height: 22)
            .foregroundColor(.blue)
    }
}

// aler content
struct PopoverContentView: View {
    var body: some View {
        VStack {
            Text("Menu")
                .font(.headline)
            
            Divider()
            
            Button("Display") {
                NSApp.activate(ignoringOtherApps: true)
            }
            .padding(5)
            
            Button("Exit") {
                NSApp.terminate(nil)
            }
            .padding(5)
        }
    }
}
