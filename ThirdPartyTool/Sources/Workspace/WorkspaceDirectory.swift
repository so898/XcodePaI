import Foundation
import Logger

/// Directory operations in workspace contexts
public struct WorkspaceDirectory {
    
    /// Determines if a directory should be skipped based on its path
    /// - Parameter url: The URL of the directory to check
    /// - Returns: `true` if the directory should be skipped, `false` otherwise
    public static func shouldSkipDirectory(_ url: URL) -> Bool {
        let path = url.path
        let normalizedPath = path.hasPrefix("/") ? path: "/" + path
        
        for skipPattern in skipPatterns {
            // Pattern: /skipPattern/ (directory anywhere in path)
            if normalizedPath.contains("/\(skipPattern)/") {
                return true
            }
            
            // Pattern: /skipPattern (directory at end of path)
            if normalizedPath.hasSuffix("/\(skipPattern)") {
                return true
            }
            
            // Pattern: skipPattern at root
            if normalizedPath == "/\(skipPattern)" {
                return true
            }
        }
        
        return false
    }
    
    /// Validates if a URL represents a valid directory for workspace operations
    /// - Parameter url: The URL to validate
    /// - Returns: `true` if the directory is valid for processing, `false` otherwise
    public static func isValidDirectory(_ url: URL) -> Bool {
        guard !WorkspaceFile.shouldSkipURL(url) else { 
            return false 
        }
        
        guard let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey]),
              resourceValues.isDirectory == true else {
            return false
        }
        
        guard !shouldSkipDirectory(url) else {
            return false
        }
        
        return true
    }
}
