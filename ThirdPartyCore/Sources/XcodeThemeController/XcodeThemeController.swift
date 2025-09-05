import AppKit
import Foundation
import Highlightr
import Logger
import XcodeInspector

public class XcodeThemeController {
    var syncTriggerTask: Task<Void, Error>? // to be removed

    public init() {
    }

    public func start() {
        let defaultHighlightrThemeManager = Highlightr.themeManager
        Highlightr.themeManager = HighlightrThemeManager(
            defaultManager: defaultHighlightrThemeManager,
            controller: self
        )

        syncXcodeThemeIfNeeded(forceRefresh: true)

        guard syncTriggerTask == nil else {
            Logger.service.error("XcodeThemeController.start() invoked multiple times.")
            return
        }

        syncTriggerTask = Task { [weak self] in
            let notifications = NSWorkspace.shared.notificationCenter
                .notifications(named: NSWorkspace.didActivateApplicationNotification)
            for await notification in notifications {
                try Task.checkCancellation()
                guard let app = notification
                    .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                else { continue }
                guard app.isCopilotForXcodeExtensionService || app.isXcode else { continue }
                guard let self else { return }
                self.syncXcodeThemeIfNeeded()
            }
        }

        Timer.scheduledTimer(
            withTimeInterval: 60,
            repeats: true
        ) { [weak self] _ in
            guard XcodeInspector.shared.activeApplication?.isXcode == true else { return }
            self?.syncXcodeThemeIfNeeded()
        }
    }
}

extension XcodeThemeController {
    func syncXcodeThemeIfNeeded(forceRefresh: Bool = false) {
        guard UserDefaults.shared.value(for: \.syncSuggestionHighlightTheme)
        else { return }
        guard let directories = createSupportDirectoriesIfNeeded() else { return }

        defer {
            UserDefaults.shared.set(
                Date().timeIntervalSince1970,
                for: \.lastSyncedHighlightJSThemeCreatedAt
            )
        }

        let xcodeUserDefaults = UserDefaults(suiteName: "com.apple.dt.Xcode")!

        if let darkThemeName = xcodeUserDefaults
            .value(forKey: "XCFontAndColorCurrentDarkTheme") as? String
        {
            syncXcodeThemeIfNeeded(
                xcodeThemeName: darkThemeName,
                light: false,
                in: directories.themeDirectory,
                forceRefresh: forceRefresh
            )
        }

        if let lightThemeName = xcodeUserDefaults
            .value(forKey: "XCFontAndColorCurrentTheme") as? String
        {
            syncXcodeThemeIfNeeded(
                xcodeThemeName: lightThemeName,
                light: true,
                in: directories.themeDirectory,
                forceRefresh: forceRefresh
            )
        }
    }

    func syncXcodeThemeIfNeeded(
        xcodeThemeName: String,
        light: Bool,
        in directoryURL: URL,
        forceRefresh: Bool = false
    ) {
        let targetName = light ? "highlightjs-light" : "highlightjs-dark"
        guard let xcodeThemeURL = locateXcodeTheme(named: xcodeThemeName) else {
            Logger.service.error("Xcode theme not found: \(xcodeThemeName)")
            return
        }
        let targetThemeURL = directoryURL.appendingPathComponent(targetName)
        let lastSyncTimestamp = UserDefaults.shared
            .value(for: \.lastSyncedHighlightJSThemeCreatedAt)

        let shouldSync = {
            if forceRefresh { return true }
            if light, UserDefaults.shared.value(for: \.lightXcodeTheme) == nil { return true }
            if !light, UserDefaults.shared.value(for: \.darkXcodeTheme) == nil { return true }
            if light, xcodeThemeName != UserDefaults.shared.value(for: \.lightXcodeThemeName) {
                return true
            }
            if !light, xcodeThemeName != UserDefaults.shared.value(for: \.darkXcodeThemeName) {
                return true
            }
            if !FileManager.default.fileExists(atPath: targetThemeURL.path) { return true }

            let xcodeThemeFileUpdated = {
                guard let xcodeThemeModifiedDate = try? xcodeThemeURL
                    .resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                else { return true }
                return xcodeThemeModifiedDate.timeIntervalSince1970 > lastSyncTimestamp
            }()

            if xcodeThemeFileUpdated { return true }

            return false
        }()

        if shouldSync {
            Logger.service.info("Syncing Xcode theme: \(xcodeThemeName)")
            do {
                let theme = try XcodeTheme(fileURL: xcodeThemeURL)
                let highlightrTheme = theme.asHighlightJSTheme()
                try highlightrTheme.write(to: targetThemeURL, atomically: true, encoding: .utf8)

                Task { @MainActor in
                    if light {
                        UserDefaults.shared.set(xcodeThemeName, for: \.lightXcodeThemeName)
                        UserDefaults.shared.set(.init(theme), for: \.lightXcodeTheme)
                        UserDefaults.shared.set(
                            .init(theme.plainTextColor.storable),
                            for: \.codeForegroundColorLight
                        )
                        UserDefaults.shared.set(
                            .init(theme.backgroundColor.storable),
                            for: \.codeBackgroundColorLight
                        )
                        UserDefaults.shared.set(
                            .init(theme.plainTextFont.storable),
                            for: \.codeFontLight
                        )
                        UserDefaults.shared.set(
                            .init(theme.currentLineColor.storable),
                            for: \.currentLineBackgroundColorLight
                        )
                    } else {
                        UserDefaults.shared.set(xcodeThemeName, for: \.darkXcodeThemeName)
                        UserDefaults.shared.set(.init(theme), for: \.darkXcodeTheme)
                        UserDefaults.shared.set(
                            .init(theme.plainTextColor.storable),
                            for: \.codeForegroundColorDark
                        )
                        UserDefaults.shared.set(
                            .init(theme.backgroundColor.storable),
                            for: \.codeBackgroundColorDark
                        )
                        UserDefaults.shared.set(
                            .init(theme.plainTextFont.storable),
                            for: \.codeFontDark
                        )
                        UserDefaults.shared.set(
                            .init(theme.currentLineColor.storable),
                            for: \.currentLineBackgroundColorDark
                        )
                    }
                }
            } catch {
                Logger.service.error("Failed to sync Xcode theme \"\(xcodeThemeName)\": \(error)")
            }
        }
    }

    func locateXcodeTheme(named name: String) -> URL? {
        if let customThemeURL = FileManager.default.urls(
            for: .libraryDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent("Developer/Xcode/UserData/FontAndColorThemes")
            .appendingPathComponent(name),
            FileManager.default.fileExists(atPath: customThemeURL.path)
        {
            return customThemeURL
        }

        let xcodeURL: URL? = {
            // Use the latest running Xcode
            if let running = XcodeInspector.shared.latestActiveXcode?.bundleURL {
                return running
            }
            // Use the main Xcode.app
            let proposedXcodeURL = URL(fileURLWithPath: "/Applications/Xcode.app")
            if FileManager.default.fileExists(atPath: proposedXcodeURL.path) {
                return proposedXcodeURL
            }
            // Look for an Xcode.app
            if let applicationsURL = FileManager.default.urls(
                for: .applicationDirectory,
                in: .localDomainMask
            ).first {
                struct InfoPlist: Codable {
                    var CFBundleIdentifier: String
                }

                let appBundleIdentifier = "com.apple.dt.Xcode"
                let appDirectories = try? FileManager.default.contentsOfDirectory(
                    at: applicationsURL,
                    includingPropertiesForKeys: [],
                    options: .skipsHiddenFiles
                )
                for appDirectoryURL in appDirectories ?? [] {
                    let infoPlistURL = appDirectoryURL.appendingPathComponent("Contents/Info.plist")
                    if let data = try? Data(contentsOf: infoPlistURL),
                       let infoPlist = try? PropertyListDecoder().decode(
                           InfoPlist.self,
                           from: data
                       ),
                       infoPlist.CFBundleIdentifier == appBundleIdentifier
                    {
                        return appDirectoryURL
                    }
                }
            }
            return nil
        }()

        if let url = xcodeURL?
            .appendingPathComponent("Contents/SharedFrameworks/DVTUserInterfaceKit.framework")
            .appendingPathComponent("Versions/A/Resources/FontAndColorThemes")
            .appendingPathComponent(name),
            FileManager.default.fileExists(atPath: url.path)
        {
            return url
        }

        return nil
    }

    func createSupportDirectoriesIfNeeded() -> (supportDirectory: URL, themeDirectory: URL)? {
        guard let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent(
            Bundle.main
                .object(forInfoDictionaryKey: "APPLICATION_SUPPORT_FOLDER") as! String
        ) else {
            Logger.service.error("Could not determine support directory for Xcode theme synching")
            return nil
        }

        let themeURL = supportURL.appendingPathComponent("Themes")

        do {
            if !FileManager.default.fileExists(atPath: supportURL.path) {
                try FileManager.default.createDirectory(
                    at: supportURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }

            if !FileManager.default.fileExists(atPath: themeURL.path) {
                try FileManager.default.createDirectory(
                    at: themeURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
        } catch {
            Logger.service.error("Failed to create support directories for Xcode theme synching: \(error)")
            return nil
        }

        return (supportURL, themeURL)
    }
}

