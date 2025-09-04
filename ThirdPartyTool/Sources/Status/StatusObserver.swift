import SwiftUI

@MainActor
public class StatusObserver: ObservableObject {
    @Published public private(set) var observedAXStatus = ObservedAXStatus.unknown
    
    public static let shared = StatusObserver()
    
    private init() {
        Task { @MainActor in
            await observeAXStatus()
        }
    }
    
    private func observeAXStatus() async {
        await updateAXStatus()
        setupAXStatusNotificationObserver()
    }
    
    private func updateAXStatus() async {
        self.observedAXStatus = await Status.shared.getAXStatus()
    }
    
    private func setupAXStatusNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: .serviceStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [self] in
                await self.updateAXStatus()
            }
        }
    }
}
