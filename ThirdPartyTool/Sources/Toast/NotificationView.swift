import SwiftUI

struct AutoDismissMessage: View {
    let message: ToastController.Message

    init(message: ToastController.Message) {
        self.message = message
    }

    var body: some View {
        message.content
            .foregroundColor(.white)
            .padding(8)
            .background(
                message.level.color as Color,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .frame(minWidth: 300)
    }
}

public struct NotificationView: View {
    let message: ToastController.Message
    let onDismiss: () -> Void
    
    public init(
        message: ToastController.Message,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.message = message
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        if let notificationTitle = message.title {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 4) {
                    Image(systemName: message.level.icon)
                        .foregroundColor(message.level.color)
                    Text(notificationTitle)

                    Spacer()

                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundColor(Color("ToastDismissButtonColor"))
                    }
                    .buttonStyle(.plain)
                }
                
                HStack(alignment: .bottom, spacing: 1) {
                    message.content

                    Spacer()

                    if let button = message.button {
                        Button(action: {
                            button.action()
                            onDismiss()
                        }) {
                            Text(button.title)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color("ToastActionButtonColor"))
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .frame(width: 450, alignment: .topLeading)
            .background(Color("ToastBackgroundColor"))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color("ToastStrokeColor"), lineWidth: 1)
            )
        } else {
            AutoDismissMessage(message: message)
                .frame(maxWidth: .infinity)
        }
    }
}
