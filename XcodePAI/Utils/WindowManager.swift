//
//  WindowManager.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/12/24.
//

import Foundation
import AppKit
import SwiftUI
import XcodeInspector

class WindowManager: NSObject, @unchecked Sendable {
    static let shared = WindowManager()
    
    private var windowControllers = [NSWindowController]()
    
    override init() {
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(receiveOpenNewCommitWindowNotificaiton), name: .init(rawValue: "OpenNewGitCommitWindow"), object: nil)
    }
    
    private func afterWindowControllerChanged() {
        if windowControllers.isEmpty {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// MARK: Setting Window
extension WindowManager {
     
    class SettingsWindow: CommandKeyOverrideWindow {
    }
    
    @MainActor
    public func openSettingsView() {
        for windowController in windowControllers {
            if let window = windowController.window as? SettingsWindow, windowController.window?.isVisible == true {
                window.close()
                return
            }
        }
        
        let settingsView = SettingsView().globalLoading()
        let hostingController = NSHostingController(rootView: settingsView)
        
        let window = SettingsWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        window.delegate = self
        window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
        window.level = .normal
        window.minSize = NSSize(width: 800, height: 600)
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.contentViewController = hostingController
        window.canBecomeKeyChecker = { true }
        
        let wc = NSWindowController(window: window)
        wc.window?.center()
        wc.window?.makeKeyAndOrderFront(nil)
        windowControllers.append(wc)
        
        afterWindowControllerChanged()
    }
}

// MARK: Record Window
extension WindowManager {
    class RecordListWindow: CommandKeyOverrideWindow {
    }
    
    func openRecordListWindow() {
        for controller in windowControllers {
            if let window = controller.window as? RecordListWindow, !window.isVisible {
                window.makeKeyAndOrderFront(nil)
                return
            } else if let window = controller.window as? RecordListWindow {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        }
        let window = RecordListWindow(
            contentRect: NSMakeRect(0, 0, (NSScreen.main?.frame.width ?? 1200) / 2, (NSScreen.main?.frame.height ?? 1000) / 2),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.delegate = self
        window.title = "Record List".localizedString
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: RecordListView())
        window.canBecomeKeyChecker = { true }
        
        let wc = NSWindowController(window: window)
        wc.showWindow(nil)
        wc.window?.center()
        wc.window?.makeKeyAndOrderFront(nil)
        windowControllers.append(wc)
        
        afterWindowControllerChanged()
    }
}

// MARK: Git Commit Window
extension WindowManager {
    
    class GitCommitWindow: CommandKeyOverrideWindow {
        var path: String?
    }
    
    @XcodeInspectorActor
    @objc func receiveOpenNewCommitWindowNotificaiton() {
        if let fileUrl = XcodeInspector.shared.safe.realtimeActiveDocumentURL {
            DispatchQueue.main.async {[weak self] in
                self?.openNewCommitWindow(with: fileUrl.path())
            }
        }
    }
    
    @MainActor
    func openNewCommitWindow(with path: String) {
        for controller in windowControllers {
            if let window = controller.window as? GitCommitWindow, window.path == path {
                controller.showWindow(nil)
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
        
        let window = GitCommitWindow(
            contentRect: NSRect(origin: .zero, size: CGSizeMake(800, 600)),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.path = path
        window.collectionBehavior = [.fullScreenAuxiliary]
        window.level = .floating
        window.delegate = self
        window.isReleasedWhenClosed = true
        window.contentView = NSHostingView(
            rootView: GitCommitView(initialPath: path)
        )
        window.canBecomeKeyChecker = { true }
        
        let wc = NSWindowController(window: window)
        wc.showWindow(nil)
        wc.window?.center()
        wc.window?.makeKeyAndOrderFront(nil)
        windowControllers.append(wc)
        
        afterWindowControllerChanged()
    }
}

extension WindowManager: NSWindowDelegate {
    func windowShouldClose(_ window: NSWindow) -> Bool {
        if let controller = window.windowController {
            windowControllers.removeAll { c in
                c == controller
            }
        }
        
        afterWindowControllerChanged()
        
        return true
    }
}

class CanBecomeKeyWindow: NSWindow {
    var canBecomeKeyChecker: () -> Bool = { true }
    override var canBecomeKey: Bool { canBecomeKeyChecker() }
    override var canBecomeMain: Bool { canBecomeKeyChecker() }
}

class CommandKeyOverrideWindow: CanBecomeKeyWindow {
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        let isCommandPressed = event.modifierFlags.contains(.command)
        
        if isCommandPressed && event.charactersIgnoringModifiers?.lowercased() == "f" {
            return
        } else if isCommandPressed && event.charactersIgnoringModifiers?.lowercased() == "q" {
            self.close()
            return
        } else if isCommandPressed && event.charactersIgnoringModifiers?.lowercased() == "w" {
            self.close()
            return
        }
        
        super.keyDown(with: event)
    }
}
