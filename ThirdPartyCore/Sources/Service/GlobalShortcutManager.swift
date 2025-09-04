import AppKit
import Combine
import Foundation
import KeyboardShortcuts
import XcodeInspector

extension KeyboardShortcuts.Name {
    static let showHideWidget = Self("ShowHideWidget")
}

@MainActor
final class GlobalShortcutManager {
    let guiController: GraphicalUserInterfaceController
    private var cancellable = Set<AnyCancellable>()

    nonisolated init(guiController: GraphicalUserInterfaceController) {
        self.guiController = guiController
    }

    func start() {
        KeyboardShortcuts.userDefaults = .shared
        setupShortcutIfNeeded()

        KeyboardShortcuts.onKeyUp(for: .showHideWidget) { [guiController] in
            let isXCodeActive = XcodeInspector.shared.activeXcode != nil

            guiController.store.send(.toggleWidgetsHotkeyPressed)

        }

        XcodeInspector.shared.$activeApplication.sink { app in
            if !UserDefaults.shared.value(for: \.showHideWidgetShortcutGlobally) {
                let shouldBeEnabled = if let app, app.isXcode || app.isExtensionService {
                    true
                } else {
                    false
                }
                if shouldBeEnabled {
                    self.setupShortcutIfNeeded()
                } else {
                    self.removeShortcutIfNeeded()
                }
            } else {
                self.setupShortcutIfNeeded()
            }
        }.store(in: &cancellable)
    }

    func setupShortcutIfNeeded() {
        KeyboardShortcuts.enable(.showHideWidget)
    }

    func removeShortcutIfNeeded() {
        KeyboardShortcuts.disable(.showHideWidget)
    }
}

