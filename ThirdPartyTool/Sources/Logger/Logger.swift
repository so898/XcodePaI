import Foundation
import os.log

enum LogLevel: String {
    case debug
    case info
    case error
}

public final class Logger: Sendable {
    private let subsystem: String
    private let category: String
    private let osLog: OSLog
    private let fileLogger = FileLogger()

    public static let service = Logger(category: "Service")
    public static let ui = Logger(category: "UI")
    public static let client = Logger(category: "Client")
    public static let updateChecker = Logger(category: "UpdateChecker")
    public static let gitHubCopilot = Logger(category: "GitHubCopilot")
    public static let langchain = Logger(category: "LangChain")
    public static let retrieval = Logger(category: "Retrieval")
    public static let license = Logger(category: "License")
    public static let `extension` = Logger(category: "Extension")
    public static let communicationBridge = Logger(category: "CommunicationBridge")
    public static let workspacePool = Logger(category: "WorkspacePool")
    public static let mcp = Logger(category: "MCP")
    public static let debug = Logger(category: "Debug")
    #if DEBUG
    /// Use a temp logger to log something temporary. I won't be available in release builds.
    public static let temp = Logger(category: "Temp")
    #endif

    public init(subsystem: String = "com.tpp.CopilotForXcode", category: String) {
        self.subsystem = subsystem
        self.category = category
        osLog = OSLog(subsystem: subsystem, category: category)
    }

    func log(
        level: LogLevel,
        message: String,
        error: Error? = nil,
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function,
        callStackSymbols: [String] = []
    ) {
        let osLogType: OSLogType
        switch level {
        case .debug:
            osLogType = .debug
        case .info:
            osLogType = .info
        case .error:
            osLogType = .error
        }

        os_log("%{public}@", log: osLog, type: osLogType, message as CVarArg)
        if category != "MCP" {
            fileLogger.log(level: level, category: category, message: message)
        }
    }

    public func debug(
        _ message: String,
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) {
        log(level: .debug, message: """
        \(message)
        file: \(file)
        line: \(line)
        function: \(function)
        """, file: file, line: line, function: function)
    }

    public func info(
        _ message: String,
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) {
        log(level: .info, message: message, file: file, line: line, function: function)
    }

    public func error(
        _ message: String,
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function,
        callStackSymbols: [String] = []
    ) {
        log(
            level: .error,
            message: message,
            file: file,
            line: line,
            function: function,
            callStackSymbols: callStackSymbols
        )
    }

    public func error(
        _ error: Error,
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function,
        callStackSymbols: [String] = Thread.callStackSymbols
    ) {
        log(
            level: .error,
            message: error.localizedDescription,
            error: error,
            file: file,
            line: line,
            function: function,
            callStackSymbols: callStackSymbols
        )
    }

    public func signpostBegin(
        name: StaticString,
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) -> Signposter {
        let poster = OSSignposter(logHandle: osLog)
        let id = poster.makeSignpostID()
        let state = poster.beginInterval(name, id: id)
        return .init(log: osLog, id: id, name: name, signposter: poster, beginState: state)
    }

    public struct Signposter {
        let log: OSLog
        let id: OSSignpostID
        let name: StaticString
        let signposter: OSSignposter
        let state: OSSignpostIntervalState

        init(
            log: OSLog,
            id: OSSignpostID,
            name: StaticString,
            signposter: OSSignposter,
            beginState: OSSignpostIntervalState
        ) {
            self.id = id
            self.log = log
            self.name = name
            self.signposter = signposter
            state = beginState
        }

        public func end() {
            signposter.endInterval(name, state)
        }

        public func event(_ text: String) {
            signposter.emitEvent(name, id: id, "\(text, privacy: .public)")
        }
    }
}

