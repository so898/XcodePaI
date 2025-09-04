import Foundation
import Logger
import CopilotForXcodeKit
import XcodeInspector

public let supportedFileExtensions: Set<String> = ["swift", "m", "mm", "h", "cpp", "c", "js", "ts", "py", "rb", "java", "applescript", "scpt", "plist", "entitlements", "md", "json", "xml", "txt", "yaml", "yml", "html", "css"]
public let skipPatterns: [String] = [
    ".git",
    ".svn",
    ".hg",
    "CVS",
    ".DS_Store",
    "Thumbs.db",
    "node_modules",
    "bower_components",
    "Preview Content",
    ".swiftpm"
]

public struct ProjectInfo {
    public let uri: String
    public let name: String
}

extension NSError {
    var isPermissionDenied: Bool {
        return (domain == NSCocoaErrorDomain && code == 257) ||
               (domain == NSPOSIXErrorDomain && code == 1)
    }
}

public struct WorkspaceFile {
    private static let wellKnownBundleExtensions: Set<String> = ["app", "xcarchive"]

    static func isXCWorkspace(_ url: URL) -> Bool {
        return url.pathExtension == "xcworkspace" && FileManager.default.fileExists(atPath: url.appendingPathComponent("contents.xcworkspacedata").path)
    }
    
    static func isXCProject(_ url: URL) -> Bool {
        return url.pathExtension == "xcodeproj" && FileManager.default.fileExists(atPath: url.appendingPathComponent("project.pbxproj").path)
    }
    
    static func isKnownPackageFolder(_ url: URL) -> Bool {
        guard wellKnownBundleExtensions.contains(url.pathExtension) else {
            return false
        }

        let resourceValues = try? url.resourceValues(forKeys: [.isPackageKey])
        return resourceValues?.isPackage == true
    }

    static func getWorkspaceByProject(_ url: URL) -> URL? {
        guard isXCProject(url) else { return nil }
        let workspaceURL = url.appendingPathComponent("project.xcworkspace")
        
        return isXCWorkspace(workspaceURL) ? workspaceURL : nil
    }

    static func getSubprojectURLs(in workspaceURL: URL) -> [URL] {
        let workspaceFile = workspaceURL.appendingPathComponent("contents.xcworkspacedata")
        do {
            let data = try Data(contentsOf: workspaceFile)
            return getSubprojectURLs(workspaceURL: workspaceURL, data: data)
        } catch let error as NSError {
            if error.isPermissionDenied {
                Logger.client.info("Permission denied for accessing file at \(workspaceFile.path)")
            } else {
                Logger.client.error("Failed to read workspace file at \(workspaceFile.path): \(error)")
            }
            return []
        }
    }

    static func getSubprojectURLs(workspaceURL: URL, data: Data) -> [URL] {
        do {
            let xml = try XMLDocument(data: data)
            let workspaceBaseURL = workspaceURL.deletingLastPathComponent()
            // Process all FileRefs and Groups recursively
            return processWorkspaceNodes(xml.rootElement()?.children ?? [], baseURL: workspaceBaseURL)
        } catch {
            Logger.client.error("Failed to parse workspace file: \(error)")
        }

        return []
    }

    /// Recursively processes all nodes in a workspace file, collecting project URLs
    private static func processWorkspaceNodes(_ nodes: [XMLNode], baseURL: URL, currentGroupPath: String = "") -> [URL] {
        var results: [URL] = []
        
        for node in nodes {
            guard let element = node as? XMLElement else { continue }

            let location = element.attribute(forName: "location")?.stringValue ?? ""
            if element.name == "FileRef" {
                if let url = resolveProjectLocation(location: location, baseURL: baseURL, groupPath: currentGroupPath),
                   !results.contains(url) {
                    results.append(url)
                }
            } else if element.name == "Group" {
                var groupPath = currentGroupPath
                if !location.isEmpty, let path = extractPathFromLocation(location) {
                    groupPath = (groupPath as NSString).appendingPathComponent(path)
                }

                // Process all children of this group, passing the updated group path
                let childResults = processWorkspaceNodes(element.children ?? [], baseURL: baseURL, currentGroupPath: groupPath)

                for url in childResults {
                    if !results.contains(url) {
                        results.append(url)
                    }
                }
            }
        }

        return results
    }

    /// Extracts path component from a location string
    private static func extractPathFromLocation(_ location: String) -> String? {
        for prefix in ["group:", "container:", "self:"] {
            if location.starts(with: prefix) {
                return location.replacingOccurrences(of: prefix, with: "")
            }
        }
        return nil
    }

    static func resolveProjectLocation(location: String, baseURL: URL, groupPath: String = "") -> URL? {
        var path = ""

        // Extract the path from the location string
        if let extractedPath = extractPathFromLocation(location) {
            path = extractedPath
        } else {
            // Unknown location format
            return nil
        }

        var url: URL = groupPath.isEmpty ? baseURL : baseURL.appendingPathComponent(groupPath)
        url = path.isEmpty ? url : url.appendingPathComponent(path)
        url = url.standardized // normalize “..” or “.” in the path
        if isXCProject(url) { // return the containing directory of the .xcodeproj file
            url.deleteLastPathComponent()
        }

        return url
    }

    static func matchesPatterns(_ url: URL, patterns: [String]) -> Bool {
        let fileName = url.lastPathComponent
        for pattern in patterns {
            if fnmatch(pattern, fileName, 0) == 0 {
                return true
            }
        }
        return false
    }

    public static func getWorkspaceInfo(workspaceURL: URL) -> WorkspaceInfo? {
        guard let projectURL = WorkspaceXcodeWindowInspector.extractProjectURL(workspaceURL: workspaceURL, documentURL: nil) else {
            return nil
        }

        let workspaceInfo = WorkspaceInfo(workspaceURL: workspaceURL, projectURL: projectURL)
        return workspaceInfo
    }

    public static func getProjects(workspace: WorkspaceInfo) -> [ProjectInfo] {
        var subprojects: [ProjectInfo] = []
        if isXCWorkspace(workspace.workspaceURL) {
            subprojects = getSubprojectURLs(in: workspace.workspaceURL).map( { projectURL in
                ProjectInfo(uri: projectURL.absoluteString, name: getDisplayNameOfXcodeWorkspace(url: projectURL))
            })
        } else {
            subprojects.append(ProjectInfo(uri: workspace.projectURL.absoluteString, name: getDisplayNameOfXcodeWorkspace(url: workspace.projectURL)))
        }
        return subprojects
    }

    public static func getDisplayNameOfXcodeWorkspace(url: URL) -> String {
        var name = url.lastPathComponent
        let suffixes = [".xcworkspace", ".xcodeproj", ".playground"]
        for suffix in suffixes {
            if name.hasSuffix(suffix) {
                name = String(name.dropLast(suffix.count))
                break
            }
        }
        return name
    }
    
    // Commom URL skip checking
    public static func shouldSkipURL(_ url: URL) -> Bool {
        return matchesPatterns(url, patterns: skipPatterns)
        || isXCWorkspace(url)
        || isXCProject(url)
        || isKnownPackageFolder(url)
        || url.pathExtension == "xcassets"
    }
    
    public static func isValidFile(
        _ url: URL,
        shouldExcludeFile: ((URL) -> Bool)? = nil
    ) throws -> Bool {
        if shouldSkipURL(url) { return false }
        
        let resourceValues = try url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
        
        // Handle directories if needed
        if resourceValues.isDirectory == true { return false }
        
        guard resourceValues.isRegularFile == true else { return false }
        if supportedFileExtensions.contains(url.pathExtension.lowercased()) == false {
            return false
        }
        
        // Apply the custom file exclusion check if provided
        if let shouldExcludeFile = shouldExcludeFile,
           shouldExcludeFile(url) { return false }
        
        return true
    }
}
