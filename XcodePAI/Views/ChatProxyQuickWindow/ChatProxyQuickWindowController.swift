//
//  ChatProxyQuickWindowController.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/12/21.
//

import Foundation
import AppKit
import XcodeInspector
import Combine
import SwiftUI

let QuickWindowHeight: CGFloat = 19

class ChatProxyQuickWindowController {
    @MainActor
    lazy var window = {
        let it = CanBecomeKeyWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        it.isReleasedWhenClosed = false
        it.isOpaque = false
        it.backgroundColor = .clear
        it.level = .floating
        it.collectionBehavior = [.fullScreenAuxiliary, .transient, .canJoinAllSpaces]
        it.hasShadow = false
        it.contentView = NSHostingView(
            rootView: QuickWindowView()
        )
        it.setIsVisible(true)
        it.canBecomeKeyChecker = { true }
        return it
    }()
    
    private var xcodeObservations = Set<AnyCancellable>()
    private var buttonObservations = Set<AnyCancellable>()
    
    func setup() {
        XcodeInspector.shared.$activeXcode.sink {[weak self] activeXcode in
            guard let `self` = self else { return }
            activeXcode?.$modelButtonAreaFrame.sink {[weak self] rect in
                guard let `self` = self else { return }
                DispatchQueue.main.async {[weak self] in
                    guard let `self` = self else { return }
                    self.updateWindow(rect)
                }
            }
            .store(in: &self.buttonObservations)
        }
        .store(in: &self.xcodeObservations)
    }
    
    @MainActor
    private func updateWindow(_ rect: NSRect?) {
        guard Configer.chatProxyQuickWindow else {
            window.alphaValue = 0
            return
        }
        guard let rect else {
            window.alphaValue = 0
            return
        }
        window.orderFrontRegardless()
        window.alphaValue = 1
        window.setFrame(
            NSRect(x: rect.origin.x, y: rect.origin.y - 18, width: rect.width, height: QuickWindowHeight),
            display: false,
            animate: false
        )
    }
}

class CanBecomeKeyWindow: NSWindow {
    var canBecomeKeyChecker: () -> Bool = { true }
    override var canBecomeKey: Bool { canBecomeKeyChecker() }
    override var canBecomeMain: Bool { canBecomeKeyChecker() }
}


