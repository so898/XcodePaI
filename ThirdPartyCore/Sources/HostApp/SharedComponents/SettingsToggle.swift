import SwiftUI

struct SettingsToggle: View {
    static let defaultPadding: CGFloat = 10
    
    let title: String
    let isOn: Binding<Bool>

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
            Spacer()
            Toggle(isOn: isOn) {}
                .toggleStyle(.switch)
        }
        .padding(SettingsToggle.defaultPadding)
    }
}

#Preview {
    SettingsToggle(title: "Test", isOn: .constant(true))
}
