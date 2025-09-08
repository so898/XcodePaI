//
//  PluginManager.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/9/9.
//

import Foundation

class PluginManager {
    static let shared = PluginManager()
    static let pluginExtension: String = "xpplugin"
    
    private var plugins: [BasePluginProtocol] = []
    
    private init() {}
    
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
            print("Error loading plugins: \(error)")
        }
    }
    
    public static func loadPlugin(_ url: URL?) -> (Bundle, PluginInfo)? {
        guard let url = url, let bundle = Bundle(url: url) else { return nil }
        
        guard bundle.load() else {
            print("Failed to load bundle: \(bundle.bundleURL.lastPathComponent)")
            return nil
        }
        
        if let pluginClass = bundle.principalClass as? BasePluginProtocol.Type {
            let plugin = pluginClass.init()
            return (bundle, PluginInfo(plugin))
        }
        
        return nil
    }
    
    func removePlugin(for identifier: String) {
        guard let plugin = plugin(for: identifier) else { return }
        plugins.removeAll { $0 === plugin }
        
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folderName = Bundle.main.object(forInfoDictionaryKey: "APPLICATION_SUPPORT_FOLDER") as! String
        let pluginsURL = appSupportURL.appendingPathComponent("\(folderName)/Plugins")
        let pluginURL = pluginsURL.appendingPathComponent("\(type(of: plugin).name).\(Self.pluginExtension)")
        
        do {
            try fileManager.removeItem(at: pluginURL)
            print("Removed plugin: \(type(of: plugin).name)")
        } catch {
            print("Error removing plugin: \(error)")
        }
    }
    
    func loadPlugin(from bundle: Bundle) {
        guard bundle.load() else {
            print("Failed to load bundle: \(bundle.bundleURL.lastPathComponent)")
            return
        }
        
        if let pluginClass = bundle.principalClass as? BasePluginProtocol.Type {
            let plugin = pluginClass.init()
            plugins.append(plugin)
            print("Loaded plugin: \(pluginClass.name)")
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

class PluginInfo: ObservableObject, Identifiable {
    let id: String
    let name: String
    let description: String
    let version: String
    
    let supportChat: Bool
    let supportCodeSuggestion: Bool
    
    init(_ plugin: BasePluginProtocol) {
        id = type(of: plugin).identifier
        name = type(of: plugin).name
        description = type(of: plugin).description
        version = type(of: plugin).version
        
        supportChat = plugin is ChatPluginProtocol
        supportCodeSuggestion = plugin is CodeSuggestionProtocol
    }
}
