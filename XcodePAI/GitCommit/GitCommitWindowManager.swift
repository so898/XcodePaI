//
//  GitCommitWindowManager.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/12/23.
//

import Foundation
import SwiftUI
import XcodeInspector

class GitCommitWindowManager: NSObject, @unchecked Sendable {
    static let shared = GitCommitWindowManager()
    
    private var windowControllers = [NSWindowController]()
    
    override init() {
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(receiveOpenNewCommitWindowNotificaiton), name: .init(rawValue: "OpenNewGitCommitWindow"), object: nil)
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
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.contentView = NSHostingView(
            rootView: GitCommitView(initialPath: path)
        )
        window.canBecomeKeyChecker = { true }
        
        let wc = NSWindowController(window: window)
        wc.showWindow(nil)
        wc.window?.center()
        wc.window?.makeKeyAndOrderFront(nil)
        windowControllers.append(wc)
    }
    
}

extension GitCommitWindowManager: NSWindowDelegate {
    func windowShouldClose(_ window: NSWindow) -> Bool {
        if let controller = window.windowController {
            windowControllers.removeAll { c in
                c == controller
            }
        }
        return true
    }
}

class GitCommitWindow: CanBecomeKeyWindow {
    var path: String?
}
