//
//  CompletionDisabledLanguageList.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/9/7.
//

import Foundation
import SwiftUI

struct CompletionDisabledLanguageList: View {
    final class Settings: ObservableObject {
        @AppStorage(\.suggestionFeatureDisabledLanguageList)
        var suggestionFeatureDisabledLanguageList: [String]
        
        init(suggestionFeatureDisabledLanguageList: AppStorage<[String]>? = nil) {
            if let list = suggestionFeatureDisabledLanguageList {
                _suggestionFeatureDisabledLanguageList = list
            }
        }
    }
    
    var isOpen: Binding<Bool>
    @State var isAddingNewProject = false
    @StateObject var settings = Settings()
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color(nsColor: .separatorColor)).frame(height: 28)
                
                HStack {
                    Button(action: {
                        self.isOpen.wrappedValue = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                    .buttonStyle(.plain)
                    Text("Disabled Languages")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                }
                .frame(height: 28)
            }
            
            List {
                ForEach(
                    settings.suggestionFeatureDisabledLanguageList,
                    id: \.self
                ) { language in
                    HStack {
                        Text(language.capitalized)
                            .contextMenu {
                                Button("Remove") {
                                    settings.suggestionFeatureDisabledLanguageList.removeAll(
                                        where: { $0 == language }
                                    )
                                }
                            }
                        Spacer()
                        
                        Button(action: {
                            settings.suggestionFeatureDisabledLanguageList.removeAll(
                                where: { $0 == language }
                            )
                        }) {
                            Image(systemName: "trash.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .modify { view in
                    if #available(macOS 13.0, *) {
                        view.listRowSeparator(.hidden).listSectionSeparator(.hidden)
                    } else {
                        view
                    }
                }
            }
            .overlay {
                if settings.suggestionFeatureDisabledLanguageList.isEmpty {
                    Text("""
                    Empty
                    Disable the language of a file from the XcodePaI menu in the status bar.
                    """)
                    .multilineTextAlignment(.center)
                    .padding()
                }
            }
        }
        .focusable(false)
        .frame(width: 300, height: 400)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
