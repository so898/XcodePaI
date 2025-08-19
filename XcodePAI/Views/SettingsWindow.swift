//
//  SettingsWindow.swift
//  XcodePAI
//
//  Created by Bill Cheng on 8/19/25.
//

import AppKit

class SettingsWindow: NSWindow {
    
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
