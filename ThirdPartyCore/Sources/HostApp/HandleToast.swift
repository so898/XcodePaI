import Dependencies
import SwiftUI
import Toast

struct ToastHandler: View {
    @ObservedObject var toastController: ToastController
    let namespace: String?

    init(toastController: ToastController, namespace: String?) {
        _toastController = .init(wrappedValue: toastController)
        self.namespace = namespace
    }

    var body: some View {
        VStack(spacing: 4) {
            ForEach(toastController.messages) { message in
                if let n = message.namespace, n != namespace {
                    EmptyView()
                } else {
                    NotificationView(message: message)
                        .shadow(color: Color.black.opacity(0.2), radius: 4)
                }
            }
        }
        .padding()
        .allowsHitTesting(false)
    }
}

extension View {
    func handleToast(namespace: String? = nil) -> some View {
        @Dependency(\.toastController) var toastController
        return overlay(alignment: .bottom) {
            ToastHandler(toastController: toastController, namespace: namespace)
        }.environment(\.toast) { [toastController] content, level in
            toastController.toast(content: content, level: level, namespace: namespace)
        }
    }
}

