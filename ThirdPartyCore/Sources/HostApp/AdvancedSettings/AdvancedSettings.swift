import SwiftUI

struct AdvancedSettings: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                SuggestionSection()
                EnterpriseSection()
                ProxySection()
                LoggingSection()
            }
            .padding(20)
        }
    }
}

#Preview {
    AdvancedSettings()
        .frame(width: 800, height: 600)
}
