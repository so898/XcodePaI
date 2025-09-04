import ComposableArchitecture
import SwiftUI

struct GeneralView: View {
    let store: StoreOf<General>
  
    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    generalView.padding(20)
                    Divider()
                    rightsView.padding(20)
                }
                .frame(maxWidth: .infinity)
            }
            .task {
                if isPreview { return }
                await store.send(.appear).finish()
            }
        }
    }

    private var generalView: some View {
        VStack(alignment: .leading, spacing: 30) {
            AppInfoView(store: store)
            GeneralSettingsView(store: store)
        }
    }

    private var rightsView: some View {
        Text("GitHub. All rights reserved.")
            .font(.caption2)
            .foregroundColor(.secondary.opacity(0.5))
    }
}

#Preview {
    GeneralView(store: .init(initialState: .init(), reducer: { General() }))
        .frame(width: 800, height: 600)
}
