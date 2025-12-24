//
//  GitManager.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/12/23.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Constants
private enum GitConstants {
    static let gitFolder = ".git"
    static let gitBinaryPath = "/usr/bin/git"
    static let patchFileExtension = ".patch"
    static let utf8Encoding = String.Encoding.utf8
}

// MARK: - GitManager
@MainActor
class GitManager: ObservableObject {
    // MARK: - Published Properties
    @Published var gitUsername: String = ""
    @Published var gitEmail: String = ""
    @Published var unstagedFiles: [GitFile] = []
    @Published var stagedFiles: [GitFile] = []
    @Published var selectedFile: GitFile?
    @Published var fileDiff: [DiffHunk] = []
    @Published var gitRepoPath: String = ""
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    
    // MARK: - Repository Operations
    
    /// Find Git repository by traversing up from the given path
    func findGitRepository(from path: String) -> String? {
        var currentPath = path as NSString
        
        while currentPath.length > 1 {
            let gitPath = currentPath.appendingPathComponent(GitConstants.gitFolder)
            if fileManager.fileExists(atPath: gitPath) {
                return currentPath as String
            }
            currentPath = currentPath.deletingLastPathComponent as NSString
        }
        return nil
    }
    
    /// Load Git status from the specified path
    func loadGitStatus(from path: String) async {
        guard let repoPath = findGitRepository(from: path) else {
            errorMessage = "Git repository not found"
            return
        }
        
        gitRepoPath = repoPath
        await refreshGitInfo()
    }
    
    /// Refresh Git information
    func refreshGitInfo() async {
        async let username = getUsername()
        async let email = getEmail()
        let unstaged = await getUnstagedFiles()
        let untracked = await getUntrackedFiles()
        async let staged = getStagedFiles()
        
        gitUsername = await username
        gitEmail = await email
        unstagedFiles.removeAll()
        unstagedFiles.append(contentsOf: unstaged)
        unstagedFiles.append(contentsOf: untracked)
        stagedFiles = await staged
    }
    
    // MARK: - Git Configuration
    
    private func getUsername() async -> String {
        let output = await runGitCommand(["config", "user.name"])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func getEmail() async -> String {
        let output = await runGitCommand(["config", "user.email"])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Get repository name
    func getRepoName() -> String {
        return (gitRepoPath as NSString).lastPathComponent
    }
    
    /// Get current branch name
    func getBranchName() async -> String {
        let output = await runGitCommand(["rev-parse", "--abbrev-ref", "HEAD"])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - File Operations
    
    private func getUnstagedFiles() async -> [GitFile] {
        let output = await runGitCommand(["diff", "--name-status"])
        return parseGitStatus(output: output, isStaged: false)
    }
    
    private func getUntrackedFiles() async -> [GitFile] {
        let output = await runGitCommand(["status", "--porcelain"])
        let files = parseGitPorcelain(output: output)
        
        var result = [GitFile]()
        for file in files {
            let filePath = (gitRepoPath as NSString).appendingPathComponent(file.path)
            if FileManager.default.fileIsDirectory(atPath: filePath) {
                if let paths = Utils.getAllFiles(in: filePath) {
                    for path in paths {
                        var newPath = path.replacingOccurrences(of: gitRepoPath, with: "")
                        if newPath.first == "/" {
                            newPath.removeFirst()
                        }
                        result.append(GitFile(path: newPath, changeType: .untracked, isStaged: false))
                    }
                }
            } else {
                result.append(file)
            }
        }
        
        return result
    }
    
    private func getStagedFiles() async -> [GitFile] {
        let output = await runGitCommand(["diff", "--cached", "--name-status"])
        return parseGitStatus(output: output, isStaged: true)
    }
    
    private func parseGitStatus(output: String, isStaged: Bool) -> [GitFile] {
        return output
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .compactMap { line -> GitFile? in
                let components = line.components(separatedBy: "\t")
                guard components.count >= 2 else { return nil }
                
                let status = components[0]
                let path = components[1]
                let changeType = GitChangeType.from(status: status)
                
                return GitFile(path: path, changeType: changeType, isStaged: isStaged)
            }
    }
    
    private func parseGitPorcelain(output: String) -> [GitFile] {
        return output
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .compactMap { line -> GitFile? in
                let components = line.components(separatedBy: " ")
                guard components.count == 2 else { return nil }
                
                let status = components[0]
                let path = components[1]
                let changeType = GitChangeType.from(status: status)
                
                if changeType == .untracked {
                    return GitFile(path: path, changeType: .untracked, isStaged: false)
                }
                
                return nil
            }
    }
    
    /// Get file content
    func getFileContent(for file: GitFile) -> String? {
        let filePath = (gitRepoPath as NSString).appendingPathComponent(file.path)
        return try? String(contentsOfFile: filePath, encoding: GitConstants.utf8Encoding)
    }
    
    /// Get file diff content
    func getDiffContent(for file: GitFile) async -> String {
        let args = file.isStaged
        ? ["diff", "--cached", "-U3", file.path]
        : ["diff", "-U3", file.path]
        
        return await runGitCommand(args)
    }
    
    func getDeletedContent(for file: GitFile) async -> String {
        return await runGitCommand(["show", "HEAD:\(file.path)"])
    }
    
    /// Load diff information for a file
    func loadDiff(for file: GitFile) async {
        selectedFile = file
        if file.changeType == .deleted {
            let output = await getDeletedContent(for: file)
            fileDiff = parseDeleted(output: output, file: file)
        } else if file.changeType == .untracked {
            fileDiff = parseUntracked(file: file)
        } else {
            let output = await getDiffContent(for: file)
            fileDiff = parseDiff(output: output, file: file)
        }
    }
    
    // MARK: - Diff Parsing
    
    private func parseDiff(output: String, file: GitFile) -> [DiffHunk] {
        var hunks: [DiffHunk] = []
        let lines = output.components(separatedBy: .newlines)
        
        var currentHunk: DiffHunk?
        var hunkLines: [DiffLine] = []
        var oldLineNum = 0
        var newLineNum = 0
        
        for line in lines {
            if line.hasPrefix("@@") {
                // Save previous hunk
                if let hunk = currentHunk {
                    hunks.append(DiffHunk(header: hunk.header, lines: hunkLines, file: file))
                }
                
                // Parse new hunk header
                let (oldStart, newStart) = parseHunkHeader(line)
                oldLineNum = oldStart
                newLineNum = newStart
                
                // Start new hunk
                currentHunk = DiffHunk(header: line, lines: [], file: file)
                hunkLines = []
                continue
            }
            
            guard let _ = currentHunk else { continue }
            
            let lineType = getDiffLineType(line)
            switch lineType {
            case .addition:
                hunkLines.append(DiffLine(
                    oldLineNum: nil,
                    newLineNum: newLineNum,
                    content: line,
                    type: .addition
                ))
                newLineNum += 1
            case .deletion:
                hunkLines.append(DiffLine(
                    oldLineNum: oldLineNum,
                    newLineNum: nil,
                    content: line,
                    type: .deletion
                ))
                oldLineNum += 1
            case .context:
                if !line.hasPrefix("\\") {
                    hunkLines.append(DiffLine(
                        oldLineNum: oldLineNum,
                        newLineNum: newLineNum,
                        content: line,
                        type: .context
                    ))
                    oldLineNum += 1
                    newLineNum += 1
                }
            }
        }
        
        // Save the last hunk
        if let hunk = currentHunk, !hunkLines.isEmpty {
            hunks.append(DiffHunk(header: hunk.header, lines: hunkLines, file: file))
        }
        
        return hunks
    }
    
    private func parseDeleted(output: String, file: GitFile) -> [DiffHunk] {
        var hunks: [DiffHunk] = []
        let lines = output.components(separatedBy: .newlines)
        
        var hunkLines: [DiffLine] = []
        
        var lineNum = 0
        for line in lines {
            hunkLines.append(DiffLine(
                oldLineNum: lineNum,
                newLineNum: nil,
                content: line,
                type: .deletion
            ))
            lineNum += 1
        }
        hunks.append(DiffHunk(header: "", lines: hunkLines, file: file))
        
        return hunks
    }
    
    private func parseUntracked(file: GitFile) -> [DiffHunk] {
        var hunks: [DiffHunk] = []
        
        guard let content = getFileContent(for: file) else {
            return hunks
        }
        let lines = content.components(separatedBy: .newlines)
        
        var hunkLines: [DiffLine] = []
        
        var lineNum = 0
        for line in lines {
            hunkLines.append(DiffLine(
                oldLineNum: nil,
                newLineNum: lineNum,
                content: line,
                type: .addition
            ))
            lineNum += 1
        }
        hunks.append(DiffHunk(header: "", lines: hunkLines, file: file))
        
        return hunks
    }
    
    private func getDiffLineType(_ line: String) -> DiffLineType {
        if line.hasPrefix("+") && !line.hasPrefix("+++") {
            return .addition
        } else if line.hasPrefix("-") && !line.hasPrefix("---") {
            return .deletion
        } else {
            return .context
        }
    }
    
    private func parseHunkHeader(_ header: String) -> (oldStart: Int, newStart: Int) {
        let pattern = #"@@\s*-(\d+)(?:,\d+)?\s*\+(\d+)(?:,\d+)?\s*@@"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: header,
                range: NSRange(header.startIndex..., in: header)
              ) else {
            return (1, 1)
        }
        
        let oldStart = Int((header as NSString).substring(with: match.range(at: 1))) ?? 1
        let newStart = Int((header as NSString).substring(with: match.range(at: 2))) ?? 1
        
        return (oldStart, newStart)
    }
    
    // MARK: - Staging Operations
    
    func stageFile(_ file: GitFile) async {
        _ = await runGitCommand(["add", file.path])
        await refreshGitStatus()
    }
    
    func stageAll() async {
        await withTaskGroup(of: Void.self) { group in
            for file in unstagedFiles {
                group.addTask { await self.stageFile(file) }
            }
        }
    }
    
    func unstageFile(_ file: GitFile) async {
        _ = await runGitCommand(["reset", "HEAD", file.path])
        await refreshGitStatus()
    }
    
    func unstageAll() async {
        await withTaskGroup(of: Void.self) { group in
            for file in stagedFiles {
                group.addTask { await self.unstageFile(file) }
            }
        }
    }
    
    func stageHunk(_ hunk: DiffHunk) async {
        await applyPatch(for: hunk, reverse: false)
    }
    
    func unstageHunk(_ hunk: DiffHunk) async {
        await applyPatch(for: hunk, reverse: true)
    }
    
    private func applyPatch(for hunk: DiffHunk, reverse: Bool) async {
        let patch = createPatch(for: hunk)
        let tempFile = createTemporaryPatchFile(patch: patch)
        defer { removeTemporaryFile(at: tempFile) }
        
        var args = ["apply", "--cached"]
        if reverse {
            args.append("--reverse")
        }
        args.append(tempFile)
        
        _ = await runGitCommand(args)
        await refreshGitStatus()
        
        if let file = selectedFile {
            await loadDiff(for: file)
        }
    }
    
    private func createPatch(for hunk: DiffHunk) -> String {
        var patch = """
        diff --git a/\(hunk.file.path) b/\(hunk.file.path)
        --- a/\(hunk.file.path)
        +++ b/\(hunk.file.path)
        \(hunk.header)
        
        """
        
        for line in hunk.lines {
            patch += line.content + "\n"
        }
        
        return patch
    }
    
    private func createTemporaryPatchFile(patch: String) -> String {
        let tempFile = NSTemporaryDirectory() + UUID().uuidString + GitConstants.patchFileExtension
        try? patch.write(toFile: tempFile, atomically: true, encoding: GitConstants.utf8Encoding)
        return tempFile
    }
    
    private func removeTemporaryFile(at path: String) {
        try? fileManager.removeItem(atPath: path)
    }
    
    private func refreshGitStatus() async {
        await loadGitStatus(from: gitRepoPath)
    }
    
    // MARK: - Commit Operations
    
    func commit(message: String) async -> Bool {
        let output = await runGitCommand(["commit", "-m", message])
        let success = !output.contains("nothing to commit")
        
        if success {
            await refreshGitStatus()
        }
        
        return success
    }
    
    // MARK: - Git Command Execution
    
    private func runGitCommand(_ args: [String]) async -> String {
        guard !gitRepoPath.isEmpty else { return "" }
        
        return await withCheckedContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: GitConstants.gitBinaryPath)
                process.arguments = args
                process.currentDirectoryURL = await URL(fileURLWithPath: self.gitRepoPath)
                
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: GitConstants.utf8Encoding) ?? ""
                    
                    await MainActor.run {
                        if process.terminationStatus != 0 && !output.isEmpty {
                            self.errorMessage = "Git command failed: \(output)"
                        }
                    }
                    
                    continuation.resume(returning: output)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Git command execution failed: \(error.localizedDescription)"
                    }
                    continuation.resume(returning: "")
                }
            }
        }
    }
}

// MARK: - Commit Message Generation Extension
extension GitManager {
    /// Generate commit message from draft
    func generateCommitMessage(_ draft: String? = nil) async throws -> String {
        defer {
            MenuBarManager.shared.stopLoading()
        }
        MenuBarManager.shared.startLoading()
        guard !stagedFiles.isEmpty else { return "" }
        
        let fileInfos = await stagedFileInfos()
        let commitHistory = await getCommitHistory(count: 10)
        let repoName = getRepoName()
        let branchName = await getBranchName()
        
        // Force return in language
        let languageContent: String = {
            switch Configer.forceLanguage {
            case .english:
                return PromptTemplate.FLEnglish
            case .chinese:
                return PromptTemplate.FLChinese
            case .french:
                return PromptTemplate.FLFrance
            case .russian:
                return PromptTemplate.FLRussian
            case .japanese:
                return PromptTemplate.FLJapanese
            case .korean:
                return PromptTemplate.FLKorean
            }
        }()
        
        var prompt = PromptTemplate.commitGenerateBase
            .replacingOccurrences(of: "<LANGUAGE>", with: languageContent)
            .replacingOccurrences(of: "<FILE_INFOS>", with: fileInfos)
            .replacingOccurrences(of: "<RECENT_HISTORY>", with: commitHistory.joined(separator: "\n"))
            .replacingOccurrences(of: "<REPO_NAME>", with: repoName)
            .replacingOccurrences(of: "<BRANCH_NAME>", with: branchName)
        
        if let draft = draft, !draft.isEmpty {
            prompt = prompt.replacingOccurrences(
                of: "<USER_DRAFT>",
                with: PromptTemplate.commitGenerateDraftSection.replacingOccurrences(of: "<DRAFT>", with: draft)
            )
        } else {
            prompt = prompt.replacingOccurrences(of: "<USER_DRAFT>", with: "")
        }

        return try await doLLMReqeust(with: prompt)
    }
    
    private func doLLMReqeust(with prompt: String) async throws -> String {
        guard let config = StorageManager.shared.defaultConfig(), let model = config.getModel(), let modelProvider = config.getModelProvider() else {
            return ""
        }
        
        var messages = [LLMMessage]()
        messages.append(LLMMessage(role: "user", content: prompt))
        
        let request = LLMRequest(model: model.id, messages:messages, stream: false, enableThinking: Configer.gitCommitGenerateUseThink)
        
        return try await LLMCompletionClient.doChatReqeust(request, provider: modelProvider, messages: messages, timeout: Configer.gitCommitGenerateTimeout)
    }
    
    private func stagedFileInfos() async -> String {
        var infos = [String]()
        
        for file in stagedFiles {
            let diff = await getDiffContent(for: file)
            let content = {
                if file.changeType == .added || file.changeType == .deleted {
                    return ""
                }
                
                if ["pbxproj", "xcscheme"].contains(((gitRepoPath as NSString).appendingPathComponent(file.path) as NSString).pathExtension)  {
                    return ""
                }
                
                return getFileContent(for: file) ?? ""
            }()
            
            infos.append(PromptTemplate.diffFileInfoTemplate(file.path, diff, content))
        }
        
        return infos.joined(separator: "\n\n")
    }
    
    private func getCommitHistory(count: Int) async -> [String] {
        let output = await runGitCommand(["log", "-n", "\(count)", "--pretty=format:%s"])
        return output.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }
}
