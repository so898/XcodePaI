import ActiveApplicationMonitor
import AppKit
import AXExtension
import BuiltinExtension
import Foundation
import Logger
import Workspace
import XcodeInspector

public final class ScheduledCleaner {
    weak var service: Service?

    init() {}

    func start() {
        Task { @ServiceActor in
            while !Task.isCancelled {
                try await Task.sleep(nanoseconds: 10 * 60 * 1_000_000_000)
                await cleanUp()
            }
        }

        Task { @ServiceActor in
            for await app in ActiveApplicationMonitor.shared.createInfoStream() {
                try Task.checkCancellation()
                if let app, !app.isXcode {
                    await cleanUp()
                }
            }
        }
    }

    @ServiceActor
    func cleanUp() async {
        guard let service else { return }

        let workspaceInfos = XcodeInspector.shared.xcodes.reduce(
            into: [
                XcodeAppInstanceInspector.WorkspaceIdentifier:
                    XcodeAppInstanceInspector.WorkspaceInfo
            ]()
        ) { result, xcode in
            let infos = xcode.realtimeWorkspaces
            for (id, info) in infos {
                if let existed = result[id] {
                    result[id] = existed.combined(with: info)
                } else {
                    result[id] = info
                }
            }
        }
        for (url, workspace) in service.workspacePool.workspaces {
            if workspace.isExpired, workspaceInfos[.url(url)] == nil {
                Logger.service.info("Remove idle workspace")
                await workspace.cleanUp(availableTabs: [])
                await service.workspacePool.removeWorkspace(url: url)
            } else {
                let tabs = (workspaceInfos[.url(url)]?.tabs ?? [])
                    .union(workspaceInfos[.unknown]?.tabs ?? [])
                // cleanup workspace
                await workspace.cleanUp(availableTabs: tabs)
            }
        }
    }

    @ServiceActor
    public func closeAllChildProcesses() async {
        BuiltinExtensionManager.shared.terminate()
    }
}

