import Foundation
import System

public final class FileLoggingLocation {
    public static let path = {
        FilePath(stringLiteral: NSHomeDirectory())
            .appending("Library")
            .appending("Logs")
            .appending("GitHubCopilot")
    }()
    
    public static let mcpRuntimeLogsPath = path.appending("MCPRuntimeLogs")
}

final class FileLogger {
    private let timestampFormat = Date.ISO8601FormatStyle.iso8601
        .year()
        .month()
        .day()
        .timeZone(separator: .omitted).time(includingFractionalSeconds: true)
    private let pid = "\(ProcessInfo.processInfo.processIdentifier)"
    private static let implementation = FileLoggerImplementation()

    private func timestamp() -> String {
        return Date().formatted(timestampFormat)
    }

    public func log(level: LogLevel, category: String, message: String) {
        let log = "[\(timestamp())] [\(level)] [\(category)] [\(pid)] \(message)\(message.hasSuffix("\n") ? "" : "\n")"

        Task {
            await FileLogger.implementation.logToFile(log)
        }
    }
}

actor FileLoggerImplementation {
    private let baseLogger: BaseFileLoggerImplementation
    
    public init() {
        baseLogger = BaseFileLoggerImplementation(
            logDir: FileLoggingLocation.path
        )
    }

    public func logToFile(_ log: String) async {
        await baseLogger.logToFile(log)
    }
}

// MARK: - Shared Base File Logger
actor BaseFileLoggerImplementation {
    #if DEBUG
    private let logBaseName = "github-copilot-for-xcode-dev"
    #else
    private let logBaseName = "github-copilot-for-xcode"
    #endif
    private let logExtension = "log"
    private let maxLogSize: Int
    private let logOverflowLimit: Int
    private let maxLogs: Int
    private let maxLockTime: Int
    
    private let logDir: FilePath
    private let logName: String
    private let lockFilePath: FilePath
    private var logStream: OutputStream?
    private var logHandle: FileHandle?
    
    init(
        logDir: FilePath,
        logFileName: String? = nil,
        maxLogSize: Int = 5_000_000,
        logOverflowLimit: Int? = nil,
        maxLogs: Int = 10,
        maxLockTime: Int = 3_600
    ) {
        self.logDir = logDir
        self.logName = (logFileName ?? logBaseName) + "." + logExtension
        self.lockFilePath = logDir.appending(logName + ".lock")
        self.maxLogSize = maxLogSize
        self.logOverflowLimit = logOverflowLimit ?? maxLogSize * 2
        self.maxLogs = maxLogs
        self.maxLockTime = maxLockTime
    }

    func logToFile(_ log: String) async {
        if let stream = logAppender() {
            let data = [UInt8](log.utf8)
            stream.write(data, maxLength: data.count)
        }
    }

    private func logAppender() -> OutputStream? {
        if logStream == nil {
            reopenLogFile()
        }

        if rotateIfNeeded() > logOverflowLimit {
            return nil // do not exceed the overflow limit
        }

        return logStream
    }

    private func reopenLogFile() {
        if !FileManager.default.fileExists(atPath: logDir.string) {
            let success: ()? = try? FileManager.default.createDirectory(atPath: logDir.string, withIntermediateDirectories: true)
            guard success != nil else { return }
        }

        let fileName = logDir.appending(logName).string
        logStream = OutputStream(toFileAtPath: fileName, append: true)
        logStream?.open()

        logHandle = FileHandle(forReadingAtPath: fileName)
    }

    private func logSize() -> UInt64{
        return logHandle?.seekToEndOfFile() ?? 0
    }

    /// @returns The resulting size of the log file
    private func rotateIfNeeded() -> UInt64 {
        let size = logSize()

        if size > maxLogSize {
            rotateLogs()
            return logSize() // return the new size of the log file
        }

        return size
    }

    private func rotateLogs() {
        // attempt to acquire a lock for rotating logs
        let fd = try? FileDescriptor.open(
            lockFilePath,
            .readWrite,
            options: .init([.create, .exclusiveCreate]),
            permissions: .init(rawValue: 0o666)
        )
        guard fd != nil else {
            // if we can't get the lock, another process is already rotating
            checkLockValidity() // prevents stale locks
            return // write to the existing log while rotation is happening
        }

        defer {
            try? fd?.close()
            try? FileManager.default.removeItem(atPath: lockFilePath.string)
        }

        // check the log size again. if it's under the limit, another process already rotated the logs
        let fileName = logDir.appending(logName).string
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileName)
        let size = (attributes?[FileAttributeKey.size] ?? 0) as! Int

        if (size > maxLogSize) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMddHHmmss"
            let archiveName = "\(logBaseName)-\(formatter.string(from: Date())).\(logExtension)"
            let newName = logDir.appending(archiveName).string

            // moving the log file does not affect any open file handles. they continue writing to the new location.
            try? FileManager.default.moveItem(atPath: fileName, toPath: newName)

            cleanupOldLogs()
        }

        reopenLogFile()
    }

    /// Note: This is only safe to call if the caller has already obtained a lock on the log directory
    private func cleanupOldLogs() {
        let logFiles = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: logDir.string), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == logExtension && $0.lastPathComponent != logName }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }

        if let oldLogFiles = logFiles, oldLogFiles.count > maxLogs {
            for fileURL in oldLogFiles[maxLogs...] {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }

    /// Checks the lock file's creation time and removes it if it is stale.
    ///
    /// If a process hangs or crashes while rotating logs, the lock file will
    /// be left behind, preventing other processes from rotating logs. To
    /// prevent this, an lock file older than the lock limit (1 hour) is
    /// considered stale and removed.
    ///
    /// The pending log entry will still be written to the existing log, but
    /// by removing the lock file, rotation will resume the next time an entry
    /// is logged.
    private func checkLockValidity() {
        let attributes = try? FileManager.default.attributesOfItem(atPath: lockFilePath.string)
        let ctime = (attributes?[FileAttributeKey.creationDate] ?? NSDate()) as! NSDate

        if ctime.timeIntervalSinceNow < -TimeInterval(maxLockTime) {
            try? FileManager.default.removeItem(atPath: lockFilePath.string)
        }
    }
}
