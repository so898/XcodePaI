import ComposableArchitecture
import Dependencies
import Foundation
import SwiftUI
import Toast

private struct HitTestConfiguration: ViewModifier {
    let hitTestPredicate: () -> Bool
    
    func body(content: Content) -> some View {
        WithPerceptionTracking {
            content.allowsHitTesting(hitTestPredicate())
        }
    }
}

struct ToastPanelView: View {
    let store: StoreOf<ToastPanel>
    @Dependency(\.toastController) var toastController

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 4) {
                if !store.alignTopToAnchor {
                    Spacer()
                        .allowsHitTesting(false)
                }

                ForEach(store.toast.messages) { message in
                    NotificationView(
                        message: message,
                        onDismiss: { toastController.dismissMessage(withId: message.id) }
                    )
                    .frame(maxWidth: 450)
                    // Allow hit testing for notification views
                    .allowsHitTesting(true)
                }

                if store.alignTopToAnchor {
                    Spacer()
                        .allowsHitTesting(false)
                }
            }
            .colorScheme(store.colorScheme)
            .background(Color.clear)
            // Only allow hit testing when there are messages
            // to prevent the view from blocking the mouse events
            .modifier(HitTestConfiguration(hitTestPredicate: { !store.toast.messages.isEmpty }))
        }
    }
}
