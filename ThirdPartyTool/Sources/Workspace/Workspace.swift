import Foundation
import Preferences
import UserDefaultsObserver
import XcodeInspector
import Logger
import UniformTypeIdentifiers

enum Environment {
    static var now = { Date() }
}

public protocol WorkspacePropertyKey {
    associatedtype Value
    static func createDefaultValue() -> Value
}

public class WorkspacePropertyValues {
    private var storage: [ObjectIdentifier: Any] = [:]

    @WorkspaceActor
    public subscript<K: WorkspacePropertyKey>(_ key: K.Type) -> K.Value {
        get {
            if let value = storage[ObjectIdentifier(key)] as? K.Value {
                return value
            }
            let value = key.createDefaultValue()
            storage[ObjectIdentifier(key)] = value
            return value
        }
        set {
            storage[ObjectIdentifier(key)] = newValue
        }
    }
}

open class WorkspacePlugin {
    public private(set) weak var workspace: Workspace?
    public var projectRootURL: URL { workspace?.projectRootURL ?? URL(fileURLWithPath: "/") }
    public var workspaceURL: URL { workspace?.workspaceURL ?? projectRootURL }
    public var filespaces: [URL: Filespace] { workspace?.filespaces ?? [:] }

    public init(workspace: Workspace) {
        self.workspace = workspace
    }

    open func didOpenFilespace(_: Filespace) {}
    open func didSaveFilespace(_: Filespace) {}
    open func didUpdateFilespace(_: Filespace, content: String) {}
    open func didCloseFilespace(_: URL) {}
}

@dynamicMemberLookup
public final class Workspace {
    public enum WorkspaceFileError: LocalizedError {
        case unsupportedFile(extensionName: String)
        case fileNotFound(fileURL: URL)
        case invalidFileFormat(fileURL: URL)
        
        public var errorDescription: String? {
            switch self {
            case .unsupportedFile(let extensionName):
                return "File type \(extensionName) unsupported."
            case .fileNotFound(let fileURL):
                return "File \(fileURL) not found."
            case .invalidFileFormat(let fileURL):
                return "The file \(fileURL.lastPathComponent) couldn't be opened because it isn't in the correct format."
            }
        }
    }

    public struct CantFindWorkspaceError: Error, LocalizedError {
        public var errorDescription: String? {
            "Can't find workspace."
        }
    }

    private var additionalProperties = WorkspacePropertyValues()
    public internal(set) var plugins = [ObjectIdentifier: WorkspacePlugin]()
    public let workspaceURL: URL
    public let projectRootURL: URL
    public let openedFileRecoverableStorage: OpenedFileRecoverableStorage
    public private(set) var lastLastUpdateTime = Environment.now()
    public var isExpired: Bool {
        Environment.now().timeIntervalSince(lastLastUpdateTime) > 60 * 60 * 1
    }

    public private(set) var filespaces = [URL: Filespace]()

    let userDefaultsObserver = UserDefaultsObserver(
        object: UserDefaults.shared, forKeyPaths: [
            UserDefaultPreferenceKeys().suggestionFeatureEnabledProjectList.key,
            UserDefaultPreferenceKeys().disableSuggestionFeatureGlobally.key,
        ], context: nil
    )

    public subscript<K>(
        dynamicMember dynamicMember: WritableKeyPath<WorkspacePropertyValues, K>
    ) -> K {
        get { additionalProperties[keyPath: dynamicMember] }
        set { additionalProperties[keyPath: dynamicMember] = newValue }
    }

    public func plugin<P: WorkspacePlugin>(for type: P.Type) -> P? {
        plugins[ObjectIdentifier(type)] as? P
    }

    init(workspaceURL: URL) {
        self.workspaceURL = workspaceURL
        self.projectRootURL = WorkspaceXcodeWindowInspector.extractProjectURL(
            workspaceURL: workspaceURL,
            documentURL: nil
        ) ?? workspaceURL
        openedFileRecoverableStorage = .init(projectRootURL: projectRootURL)
        let openedFiles = openedFileRecoverableStorage.openedFiles
        Task { @WorkspaceActor in
            for fileURL in openedFiles {
                do {
                    _ = try createFilespaceIfNeeded(fileURL: fileURL)
                } catch _ as WorkspaceFileError {
                    openedFileRecoverableStorage.closeFile(fileURL: fileURL)
                } catch {
                    Logger.workspacePool.error(error)
                }
            }
        }
    }

    public func refreshUpdateTime() {
        lastLastUpdateTime = Environment.now()
    }

    @WorkspaceActor
    public func createFilespaceIfNeeded(fileURL: URL) throws -> Filespace {
        let extensionName = fileURL.pathExtension
        
        if ["xcworkspace", "xcodeproj"].contains(
            extensionName
        ) || FileManager.default
            .fileIsDirectory(atPath: fileURL.path) {
            throw WorkspaceFileError.unsupportedFile(extensionName: extensionName)
        }
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw WorkspaceFileError.fileNotFound(fileURL: fileURL)
        }
        
        if let contentType = try fileURL.resourceValues(forKeys: [.contentTypeKey]).contentType,
           !contentType.conforms(to: UTType.data) {
            throw WorkspaceFileError.invalidFileFormat(fileURL: fileURL)
        }
        
        let existedFilespace = filespaces[fileURL]
        let filespace = existedFilespace ?? .init(
            fileURL: fileURL,
            onSave: { [weak self] filespace in
                guard let self else { return }
                self.didSaveFilespace(filespace)
            },
            onClose: { [weak self] url in
                guard let self else { return }
                self.didCloseFilespace(url)
            }
        )
        if filespaces[fileURL] == nil {
            filespaces[fileURL] = filespace
        }
        if existedFilespace == nil {
            didOpenFilespace(filespace)
        } else {
            filespace.refreshUpdateTime()
        }
        return filespace
    }

    @WorkspaceActor
    public func closeFilespace(fileURL: URL) {
        filespaces[fileURL] = nil
    }

    @WorkspaceActor
    public func didUpdateFilespace(fileURL: URL, content: String) {
        refreshUpdateTime()
        guard let filespace = filespaces[fileURL] else { return }
        filespace.bumpVersion()
        filespace.refreshUpdateTime()
        for plugin in plugins.values {
            plugin.didUpdateFilespace(filespace, content: content)
        }
    }

    @WorkspaceActor
    func didOpenFilespace(_ filespace: Filespace) {
        refreshUpdateTime()
        openedFileRecoverableStorage.openFile(fileURL: filespace.fileURL)
        for plugin in plugins.values {
            plugin.didOpenFilespace(filespace)
        }
    }

    @WorkspaceActor
    func didCloseFilespace(_ fileURL: URL) {
        for plugin in self.plugins.values {
            plugin.didCloseFilespace(fileURL)
        }
    }

    @WorkspaceActor
    func didSaveFilespace(_ filespace: Filespace) {
        refreshUpdateTime()
        filespace.refreshUpdateTime()
        for plugin in plugins.values {
            plugin.didSaveFilespace(filespace)
        }
    }
}

