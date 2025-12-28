//
//  GitCommitView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/12/23.
//

import SwiftUI

// MARK: - Git Commit View
struct GitCommitView: View {
    @StateObject private var gitManager = GitManager()
    @State private var commitMessage = ""
    @State private var alertState = AlertState()
    @State private var generatingCommit = false
    @StateObject private var languageManager = LanguageManager.shared
    
    let initialPath: String
    let titleText: (_ title: String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            MainSplitView(gitManager: gitManager)
            
            Divider()
            
            CommitSection(
                gitManager: gitManager,
                commitMessage: $commitMessage,
                generatingCommit: $generatingCommit,
                onRefresh: refreshGitInfo,
                onGenerateCommitMessage: {
                    Task {
                        generatingCommit = true
                        do {
                            let result = try await gitManager.generateCommitMessage(commitMessage)
                            if !result.isEmpty {
                                commitMessage = result
                            }
                        } catch {
                            alertState = AlertState(
                                message: error.localizedDescription,
                                isPresented: true
                            )
                        }
                        generatingCommit = false
                    }
                },
                onCommit: { performCommit() }
            )
            .frame(height: 140)
            
        }
        .alert(alertState.title, isPresented: $alertState.isPresented) {
            Button("OK", role: .cancel) { }
                .keyboardShortcut(.defaultAction)
        } message: {
            Text(alertState.message)
        }
        .task {
            await gitManager.loadGitStatus(from: initialPath)
            titleText("\(gitManager.getRepoName()) - \(await gitManager.getBranchName())")
        }
        .sheet(isPresented: $generatingCommit, content: {
            loadingOverlay
        })
        .environment(\.locale, languageManager.currentLanguage == nil ? .current : .init(identifier: languageManager.currentLanguage!))
    }
    
    private var loadingOverlay: some View {
        Group {
            ZStack {
                // Loading
                HStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                    
                    Text("Generating…".localizedString)
                        .foregroundColor(.primary)
                        .font(.headline)
                }
                .padding(30)
            }
            .zIndex(999) // On the top
            .transition(.opacity)
        }
    }
    
    // MARK: - Private Methods
    private func refreshGitInfo() {
        Task {
            await gitManager.refreshGitInfo()
        }
    }
    
    private func performCommit() {
        Task {
            await commitAction()
        }
    }
    
    private func commitAction() async {
        guard validateCommit() else { return }
        
        let success = await gitManager.commit(message: commitMessage)
        alertState = AlertState(
            message: success ? "Commit successful!".localizedString : "Commit failed".localizedString,
            isPresented: true
        )
        
        if success {
            gitManager.selectedFile = nil
            commitMessage = ""
        }
    }
    
    private func validateCommit() -> Bool {
        guard !commitMessage.isEmpty else {
            alertState = AlertState(message: "Please enter commit message".localizedString, isPresented: true)
            return false
        }
        
        guard !gitManager.stagedFiles.isEmpty else {
            alertState = AlertState(message: "No staged files".localizedString, isPresented: true)
            return false
        }
        
        return true
    }
}

// MARK: - Supporting Models
struct AlertState {
    let title = "Alert".localizedString
    var message = ""
    var isPresented = false
    
    init(message: String = "", isPresented: Bool = false) {
        self.message = message
        self.isPresented = isPresented
    }
}

// MARK: - Main Split View
struct MainSplitView: View {
    @ObservedObject var gitManager: GitManager
    
    var body: some View {
        HSplitView {
            FileListSection(gitManager: gitManager)
                .frame(minWidth: 250, maxWidth: 400)
            
            DiffView(gitManager: gitManager)
        }
        .frame(minHeight: 400)
    }
}

// MARK: - File List Section
struct FileListSection: View {
    @ObservedObject var gitManager: GitManager
    
    var body: some View {
        VStack(spacing: 0) {
            UnstagedFilesView(gitManager: gitManager)
            Divider()
            StagedFilesView(gitManager: gitManager)
        }
    }
}

// MARK: - File List Views
struct FileListView<Files: RandomAccessCollection>: View where Files.Element == GitFile {
    let title: String
    let files: Files
    let primaryActionTitle: String
    let primaryAction: () -> Void
    let fileAction: (GitFile) -> Void
    let fileTapAction: (GitFile) -> Void
    let selectedFile: GitFile?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FileListHeader(
                title: title,
                count: files.count,
                actionTitle: primaryActionTitle,
                action: primaryAction
            )
            
            List(files) { file in
                FileRowView(
                    file: file,
                    actionIcon: actionIcon(for: file),
                    onAction: { fileAction(file) },
                    onTap: { fileTapAction(file) },
                    isSelected: selectedFile?.id == file.id
                )
            }
            .listStyle(.sidebar)
        }
    }
    
    private func actionIcon(for file: GitFile) -> String {
        return file.isStaged ? "minus.circle" : "plus.circle"
    }
}

// MARK: - Unstaged Files View
struct UnstagedFilesView: View {
    @ObservedObject var gitManager: GitManager
    
    var body: some View {
        FileListView(
            title: "Unstaged Changes".localizedString,
            files: gitManager.unstagedFiles,
            primaryActionTitle: "Stage All".localizedString,
            primaryAction: { Task { await gitManager.stageAll() } },
            fileAction: { file in Task { await gitManager.stageFile(file) } },
            fileTapAction: { file in Task { await gitManager.loadDiff(for: file) } },
            selectedFile: gitManager.selectedFile
        )
    }
}

// MARK: - Staged Files View
struct StagedFilesView: View {
    @ObservedObject var gitManager: GitManager
    
    var body: some View {
        FileListView(
            title: "Staged Changes".localizedString,
            files: gitManager.stagedFiles,
            primaryActionTitle: "Unstage All".localizedString,
            primaryAction: { Task { await gitManager.unstageAll() } },
            fileAction: { file in Task { await gitManager.unstageFile(file) } },
            fileTapAction: { file in Task { await gitManager.loadDiff(for: file) } },
            selectedFile: gitManager.selectedFile
        )
    }
}

// MARK: - File List Header
struct FileListHeader: View {
    let title: String
    let count: Int
    let actionTitle: String
    let action: () -> Void
    
    var body: some View {
        HStack {
            Text("\(title) (\(count))")
                .font(.headline)
            Spacer()
            Button(actionTitle, action: action)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
    }
}

// MARK: - File Row View
struct FileRowView: View {
    let file: GitFile
    let actionIcon: String
    let onAction: () -> Void
    let onTap: () -> Void
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Text(file.changeType.icon)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(file.changeType.color)
                .frame(width: 20)
            
            Text(file.path)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            Button(action: onAction) {
                Image(systemName: actionIcon)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .help(file.isStaged ? "Unstage file".localizedString : "Stage file".localizedString)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .background(
            isSelected ? Color.accentColor.opacity(0.2) : Color.clear
        )
    }
}

// MARK: - Diff View
struct DiffView: View {
    @ObservedObject var gitManager: GitManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let file = gitManager.selectedFile {
                FileHeaderView(fileName: file.path)
                DiffContentView(diffHunks: gitManager.fileDiff, gitManager: gitManager)
            } else {
                EmptyDiffView()
            }
        }
    }
}

// MARK: - Diff Subviews
struct FileHeaderView: View {
    let fileName: String
    
    var body: some View {
        Text(fileName)
            .font(.headline)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.1))
    }
}

struct DiffContentView: View {
    let diffHunks: [DiffHunk]
    @ObservedObject var gitManager: GitManager
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(diffHunks) { hunk in
                    DiffHunkView(hunk: hunk, gitManager: gitManager)
                }
            }
            .padding()
        }
    }
}

struct EmptyDiffView: View {
    var body: some View {
        VStack {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.secondary)
                .padding()
            
            Text("Select a file to view diff")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
// MARK: - Diff Hunk View
struct DiffHunkView: View {
    let hunk: DiffHunk
    @ObservedObject var gitManager: GitManager
    
    private var buttonTitle: String {
        hunk.file.isStaged ? "Unstage".localizedString : "Stage".localizedString
    }
    
    private var buttonAction: () -> Void {
        {
            Task {
                if hunk.file.isStaged {
                    await gitManager.unstageHunk(hunk)
                } else {
                    if hunk.file.changeType == .untracked {
                        await gitManager.stageFile(hunk.file)
                    } else {
                        await gitManager.stageHunk(hunk)
                    }
                }
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HunkHeaderView(
                header: hunk.header,
                buttonTitle: buttonTitle,
                buttonAction: buttonAction
            )
            
            HunkContentView(lines: hunk.lines)
        }
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

struct HunkHeaderView: View {
    let header: String
    let buttonTitle: String
    let buttonAction: () -> Void
    
    var body: some View {
        HStack {
            Text(header)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(buttonTitle, action: buttonAction)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(8)
        .background(Color.gray.opacity(0.15))
    }
}

struct HunkContentView: View {
    let lines: [DiffLine]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(lines) { line in
                DiffLineView(line: line)
            }
        }
    }
}

// MARK: - Diff Line View
struct DiffLineView: View {
    let line: DiffLine
    
    private var textColor: Color {
        switch line.type {
        case .addition: return .green
        case .deletion: return .red
        case .context: return .primary
        }
    }
    
    private var backgroundColor: Color {
        switch line.type {
        case .addition: return Color.green.opacity(0.1)
        case .deletion: return Color.red.opacity(0.1)
        case .context: return Color.clear
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            let oldLineNum = {
                if let lineNum = line.oldLineNum {
                    return String(lineNum)
                }
                return ""
            }()
            Text(oldLineNum)
                .frame(width: 40, alignment: .center)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
            
            let newLineNum = {
                if let lineNum = line.newLineNum {
                    return String(lineNum)
                }
                return ""
            }()
            Text(newLineNum)
                .frame(width: 40, alignment: .center)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
            
            Text(line.content)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(textColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
    }
}

// MARK: - Commit Section
struct CommitSection: View {
    @EnvironmentObject private var loadingState: LoadingState
    
    @ObservedObject var gitManager: GitManager
    @Binding var commitMessage: String
    @Binding var generatingCommit: Bool
    let onRefresh: () -> Void
    let onGenerateCommitMessage: () -> Void
    let onCommit: () -> Void
    
    private var isCommitDisabled: Bool {
        commitMessage.isEmpty || gitManager.stagedFiles.isEmpty
    }
    
    private var generateButtonTitle: String {
        commitMessage.isEmpty ? "Generate Commit Message".localizedString : "Optimize Commit Message".localizedString
    }
    
    var body: some View {
        VStack(spacing: 12) {
            AuthorInfoView(username: gitManager.gitUsername, email: gitManager.gitEmail)
            
            CommitMessageEditor(text: $commitMessage)
            
            ActionButtons(
                onRefresh: onRefresh,
                onGenerate: onGenerateCommitMessage,
                generateButtonTitle: generateButtonTitle,
                onCommit: onCommit,
                isGenerateDisabled: gitManager.stagedFiles.isEmpty || generatingCommit,
                isCommitDisabled: isCommitDisabled
            )
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
    }
}

// MARK: - Commit Subviews
struct AuthorInfoView: View {
    let username: String
    let email: String
    
    var body: some View {
        HStack {
            Text("Author: \(username) (\(email))")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

struct CommitMessageEditor: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 12))
            .focused($isFocused)
            .frame(minHeight: 60)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                if text.isEmpty && !isFocused {
                    Text("Enter commit message…")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
    }
}

struct ActionButtons: View {
    let onRefresh: () -> Void
    let onGenerate: () -> Void
    let generateButtonTitle: String
    let onCommit: () -> Void
    let isGenerateDisabled: Bool
    let isCommitDisabled: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.borderless)
            .help("Refresh git status".localizedString)
            .keyboardShortcut(.init("r", modifiers: [.command]))
            
            Spacer()
            Button {
                onGenerate()
            } label: {
                Text(generateButtonTitle)
                Text("⌘G")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.bordered)
            .disabled(isGenerateDisabled)
            .keyboardShortcut(.init("g", modifiers: [.command]))
            
            Button {
                onCommit()
            } label: {
                Text("Commit")
                Text("⌘⏎")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isCommitDisabled)
            .keyboardShortcut(.init(.return, modifiers: [.command]))

        }
    }
}
