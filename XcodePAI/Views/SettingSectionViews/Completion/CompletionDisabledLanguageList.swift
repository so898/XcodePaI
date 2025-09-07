//
//  CompletionDisabledLanguageList.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/9/7.
//

import Foundation
import SwiftUI
import SuggestionBasic

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
                ForEach(LanguageIdentifier.allCases, id: \.rawValue) { languageId in
                    HStack {
                        Text(languageId.rawValue)
                        Spacer()
                        Toggle("", isOn: Binding(get: {
                            settings.suggestionFeatureDisabledLanguageList.contains(where: { id in
                                return languageId.rawValue == id
                            })
                        }, set: { value, _ in
                            if value {
                                settings.suggestionFeatureDisabledLanguageList.append(languageId.rawValue)
                            } else {
                                var newList = [String]()
                                for value in settings.suggestionFeatureDisabledLanguageList {
                                    if value != languageId.rawValue {
                                        newList.append(value)
                                    }
                                }
                                settings.suggestionFeatureDisabledLanguageList = newList
                            }
                        }))
                        .toggleStyle(.checkbox)
                    }
                }
            }
        }
        .focusable(false)
        .frame(width: 300, height: 400)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
