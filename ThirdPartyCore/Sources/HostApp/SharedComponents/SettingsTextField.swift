import SwiftUI

struct SettingsTextField: View {
    let title: String
    let prompt: String
    @Binding var text: String
    let isSecure: Bool
    
    @State private var localText: String = ""
    @State private var debounceTimer: Timer?
    
    var onDebouncedChange: ((String) -> Void)?
    
    init(title: String, prompt: String, text: Binding<String>, isSecure: Bool = false, onDebouncedChange: ((String) -> Void)? = nil) {
        self.title = title
        self.prompt = prompt
        self._text = text
        self.isSecure = isSecure
        self.onDebouncedChange = onDebouncedChange
        self._localText = State(initialValue: text.wrappedValue)
    }

    var body: some View {
        Form {
            Group {
                if isSecure {
                    SecureField(text: $localText, prompt: Text(prompt)) {
                        Text(title)
                    }
                } else {
                    TextField(text: $localText, prompt: Text(prompt)) {
                        Text(title)
                    }
                }
            }
            .textFieldStyle(.plain)
            .multilineTextAlignment(.trailing)
            .onChange(of: localText) { newValue in
                text = newValue
                debounceTimer?.invalidate()
                debounceTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                    onDebouncedChange?(newValue)
                }
            }
            .onAppear {
                localText = text
            }
        }
        .padding(10)
    }
}

#Preview {
    VStack(spacing: 10) {
        SettingsTextField(
            title: "Username",
            prompt: "user",
            text: .constant("")
        )
        Divider()
        SettingsTextField(
            title: "Password",
            prompt: "pass",
            text: .constant(""),
            isSecure: true
        )
    }
    .padding(.vertical, 10)
}
