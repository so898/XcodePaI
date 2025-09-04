import SwiftUI
import AppKit

public enum CheckboxMixedState {
    case off, mixed, on
}

public struct MixedStateCheckbox: View {
    let title: String
    let action: () -> Void
    
    @Binding var state: CheckboxMixedState
    
    public init(title: String, state: Binding<CheckboxMixedState>, action: @escaping () -> Void) {
        self.title = title
        self.action = action
        self._state = state
    }
    
    public var body: some View {
        MixedStateCheckboxView(title: title, state: state, action: action)
    }
}

private struct MixedStateCheckboxView: NSViewRepresentable {
    let title: String
    let state: CheckboxMixedState
    let action: () -> Void
    
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.setButtonType(.switch)
        button.allowsMixedState = true
        button.title = title
        button.target = context.coordinator
        button.action = #selector(Coordinator.onButtonClicked)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }
    
    class Coordinator: NSObject {
        let action: () -> Void
        
        init(action: @escaping () -> Void) {
            self.action = action
        }
        
        @objc func onButtonClicked() {
            action()
        }
    }
    
    func updateNSView(_ nsView: NSButton, context: Context) {
        nsView.title = title
        
        switch state {
        case .off:
            nsView.state = .off
        case .mixed:
            nsView.state = .mixed
        case .on:
            nsView.state = .on
        }
    }
}
