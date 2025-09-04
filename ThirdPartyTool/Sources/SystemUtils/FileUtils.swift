import Foundation

public struct FileUtils{
    public typealias ReadabilityErrorMessageProvider = (ReadabilityStatus) -> String?
    
    public enum ReadabilityStatus {
        case readable
        case notFound
        case permissionDenied
        
        public var isReadable: Bool {
            switch self {
            case .readable: true
            case .notFound, .permissionDenied: false
            }
        }
        
        public func errorMessage(using provider: ReadabilityErrorMessageProvider? = nil) -> String? {
            if let provider = provider {
                return provider(self)
            }
            
            // Default error messages
            switch self {
            case .readable:
                return nil
            case .notFound:
                return "File may have been removed or is unavailable."
            case .permissionDenied:
                return "Permission Denied to access file."
            }
        }
    }
    
    public static func checkFileReadability(at path: String) -> ReadabilityStatus {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: path) {
            if fileManager.isReadableFile(atPath: path) {
                return .readable
            } else {
                return .permissionDenied
            }
        } else {
            return .notFound
        }
    }
}
