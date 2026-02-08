//
//  PluginManager.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/9/9.
//

import Foundation
import Logger

class PluginManager {
    static let shared = PluginManager()
    static let pluginExtension: String = "plugin"
    
    private var plugins: [BasePluginProtocol] = []
    private var selectedPlugin: BasePluginProtocol?
    
    private var currentWorkspaceUrl: URL?
    private var currentRootProjectUrl: URL?
    
    private init() {
        loadPlugins()
        updateSelectePlugin(id: Configer.selectedPluginId)
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateWorkspaceURL(_:)), name:.workspaceURLChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateProjectRootURL(_:)), name:.projectRootURLChanged, object: nil)
    }
    
    // Load plugins
    func loadPlugins() {
        plugins.removeAll()
        
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folderName = Bundle.main.object(forInfoDictionaryKey: "APPLICATION_SUPPORT_FOLDER") as! String
        let pluginsURL = appSupportURL.appendingPathComponent("\(folderName)/Plugins")
        
        // Make directory if not exist
        if !fileManager.fileExists(atPath: pluginsURL.path) {
            try? fileManager.createDirectory(at: pluginsURL, withIntermediateDirectories: true, attributes: nil)
            return
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: pluginsURL, includingPropertiesForKeys: nil, options: [])
            for url in contents where url.pathExtension == Self.pluginExtension {
                if let bundle = Bundle(url: url) {
                    loadPlugin(from: bundle)
                }
            }
        } catch {
            Logger.extension.error("Error loading plugins: \(error.localizedDescription)")
        }
    }
    
    func updateSelectePlugin(id: String?) {
        guard let id else {
            selectedPlugin = nil
            return
        }
        
        for plugin in plugins {
            if type(of: plugin).identifier == id {
                selectedPlugin = plugin
                break
            }
        }
    }
    
    func getChatPlugin() -> ChatPluginProtocol? {
        guard let selectedPlugin = selectedPlugin as? ChatPluginProtocol else {
            return nil
        }
        
        return selectedPlugin
    }
    
    func getCodeSuggestionPlugin() -> CodeSuggestionPLuginProtocol? {
        guard let selectedPlugin = selectedPlugin as? CodeSuggestionPLuginProtocol else {
            return nil
        }
        
        return selectedPlugin
    }
    
    public static func loadPlugin(_ url: URL?) -> (Bundle, PluginInfo)? {
        guard let url = url, let bundle = Bundle(url: url) else { return nil }
        
        guard bundle.load() else {
            Logger.extension.error("Failed to load bundle: \(bundle.bundleURL.lastPathComponent)")
            return nil
        }
        
        if let pluginClass = bundle.principalClass as? BasePluginProtocol.Type {
            let plugin = pluginClass.init()
            return (bundle, PluginInfo(plugin))
        }
        
        return nil
    }
    
    func addPlugin(from url: URL) {
        if let (bundle, pluginInfo) = Self.loadPlugin(url) {
            let fileManager = FileManager.default
            let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let folderName = Bundle.main.object(forInfoDictionaryKey: "APPLICATION_SUPPORT_FOLDER") as! String
            let pluginsURL = appSupportURL.appendingPathComponent("\(folderName)/Plugins")
            do {
                try fileManager.copyItem(at: url, to: pluginsURL.appending(component: pluginInfo.id).appendingPathExtension(Self.pluginExtension))
            } catch {
                Logger.extension.error("Error adding plugin: \(error.localizedDescription)")
            }
            loadPlugin(from: bundle)
            Logger.extension.info("Added plugin: \(pluginInfo.name)")
        }
    }
    
    func removePlugin(for identifier: String) {
        guard let plugin = plugin(for: identifier) else { return }
        plugins.removeAll { $0 === plugin }
        
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folderName = Bundle.main.object(forInfoDictionaryKey: "APPLICATION_SUPPORT_FOLDER") as! String
        let pluginsURL = appSupportURL.appendingPathComponent("\(folderName)/Plugins")
        let pluginURL = pluginsURL.appendingPathComponent("\(identifier).\(Self.pluginExtension)")
        
        do {
            try fileManager.removeItem(at: pluginURL)
            Logger.extension.info("Removed plugin: \(type(of: plugin).name)")
        } catch {
            Logger.extension.error("Error removing plugin: \(error.localizedDescription)")
        }
    }
    
    private func loadPlugin(from bundle: Bundle) {
        guard bundle.load() else {
            Logger.extension.error("Failed to load bundle: \(bundle.bundleURL.lastPathComponent)")
            return
        }
        
        if let pluginClass = bundle.principalClass as? BasePluginProtocol.Type {
            let plugin = pluginClass.init()
            plugins.append(plugin)
            Logger.extension.info("Loaded plugin: \(pluginClass.name)")
        }
    }
    
    func getAllPlugins() -> [BasePluginProtocol] {
        return plugins
    }
    
    func getAllPluginInfos() -> [PluginInfo] {
        return plugins.map { PluginInfo($0) }
    }
    
    func plugin(for identifier: String) -> BasePluginProtocol? {
        return plugins.first { type(of: $0).identifier == identifier }
    }
}

extension PluginManager {
    @objc private func updateWorkspaceURL(_ notificaton: Notification) {
        guard let url = notificaton.object as? URL else {
            currentWorkspaceUrl = nil
            return
        }
        currentWorkspaceUrl = url
        updatePluginURLInfo()
    }
    
    @objc private func updateProjectRootURL(_ notificaton: Notification) {
        guard let url = notificaton.object as? URL else {
            currentRootProjectUrl = nil
            return
        }
        currentRootProjectUrl = url
        updatePluginURLInfo()
    }
    
    private func updatePluginURLInfo() {
        selectedPlugin?.update(projectUrl: currentRootProjectUrl, workspaceUrl: currentWorkspaceUrl)
    }
}

class PluginInfo: ObservableObject, Identifiable {
    let id: String
    let name: String
    let description: String
    let version: String
    let link: String
    
    let supportChat: Bool
    let supportCodeSuggestion: Bool
    
    init(_ plugin: BasePluginProtocol) {
        id = type(of: plugin).identifier
        name = type(of: plugin).name
        description = type(of: plugin).pluginDescription
        version = type(of: plugin).pluginVersion
        link = type(of: plugin).link
        
        supportChat = plugin is ChatPluginProtocol
        supportCodeSuggestion = plugin is CodeSuggestionPLuginProtocol
    }
}
