import Foundation
import GitHubCopilotService

extension NSError {
    static func from(_ error: Error) -> NSError {
        if let error = error as? CancellationError {
            return NSError(domain: "com.tpp.CopilotForXcode", code: -100, userInfo: [
                NSLocalizedDescriptionKey: error.localizedDescription,
            ])
        }
        return NSError(domain: "com.tpp.CopilotForXcode", code: -1, userInfo: [
            NSLocalizedDescriptionKey: error.localizedDescription,
        ])
    }
}
