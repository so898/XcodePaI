import SwiftUI

struct SuggestionSection: View {
    @AppStorage(\.realtimeSuggestionToggle) var realtimeSuggestionToggle
    @AppStorage(\.suggestionFeatureEnabledProjectList) var suggestionFeatureEnabledProjectList
    @AppStorage(\.acceptSuggestionWithTab) var acceptSuggestionWithTab
    @State var isSuggestionFeatureDisabledLanguageListViewOpen = false
    @State private var shouldPresentTurnoffSheet = false

    var realtimeSuggestionBinding : Binding<Bool> {
        Binding(
            get: { realtimeSuggestionToggle },
            set: {
                if !$0 {
                    shouldPresentTurnoffSheet = true
                } else {
                    realtimeSuggestionToggle = $0
                }
            }
        )
    }

    var body: some View {
        SettingsSection(title: "Suggestion Settings") {
            SettingsToggle(
                title: "Request suggestions while typing",
                isOn: realtimeSuggestionBinding
            )
            Divider()
            SettingsToggle(
                title: "Accept suggestions with Tab",
                isOn: $acceptSuggestionWithTab
            )
        } footer: {
            HStack {
                Spacer()
                Button("Disabled language list") {
                    isSuggestionFeatureDisabledLanguageListViewOpen = true
                }
            }
        }
        .sheet(isPresented: $isSuggestionFeatureDisabledLanguageListViewOpen) {
            DisabledLanguageList(isOpen: $isSuggestionFeatureDisabledLanguageListViewOpen)
        }
        .alert(
            "Disable suggestions while typing",
            isPresented: $shouldPresentTurnoffSheet
        ) {
            Button("Disable") { realtimeSuggestionToggle = false }
            Button("Cancel", role: .cancel, action: {})
        } message: {
            Text("""
                If you disable requesting suggestions while typing, you will \
                not see any suggestions until requested manually.
                """)
        }
    }
}

#Preview {
    SuggestionSection()
}
