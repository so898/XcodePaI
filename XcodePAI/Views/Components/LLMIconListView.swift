//
//  LLMIconListView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/13.
//

import SwiftUI

struct LLMIcon: Identifiable {
    let id = UUID()
    let iconName: String
    let name: String
}

struct LLMIconListView: View {
    @Binding var isPresented: Bool
    @Binding var choosedIconName: String
    
    let icons: [LLMIcon] = [
        .init(iconName: "openai", name: "OpenAI"),
        .init(iconName: "ollama", name: "Ollama"),
        .init(iconName: "deepseek", name: "DeepSeek"),
        .init(iconName: "claude", name: "Claude"),
        .init(iconName: "qwen", name: "Qwen"),
        .init(iconName: "llamaindex", name: "Llama"),
        .init(iconName: "gemini", name: "Gemini"),
        .init(iconName: "grok", name: "Grok"),
        .init(iconName: "doubao", name: "Doubao"),
        .init(iconName: "llava", name: "Llava"),
        .init(iconName: "mistral", name: "Mistral"),
        .init(iconName: "kimi", name: "Kimi"),
        .init(iconName: "alibaba", name: "Alibaba"),
        .init(iconName: "anthropic", name: "Anthropic"),
        .init(iconName: "aws", name: "AWS"),
        .init(iconName: "azure", name: "Azure"),
        .init(iconName: "google", name: "Google"),
        .init(iconName: "microsoft", name: "Microsoft"),
        .init(iconName: "siliconcloud", name: "SiliconCloud"),
        .init(iconName: "volcengine", name: "VolcEngine"),
        .init(iconName: "moonshot", name: "MoonShot"),
        .init(iconName: "openrouter", name: "OpenRouter"),
        .init(iconName: "n8n", name: "n8n"),
        .init(iconName: "openwebui", name: "OpenWebUI"),
        .init(iconName: "lmstudio", name: "LMStudio"),
        .init(iconName: "vllm", name: "vllm"),
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.fixed(64)),
                    GridItem(.fixed(64)),
                    GridItem(.fixed(64)),
                    GridItem(.fixed(64))
                ],
                alignment: .leading,
                spacing: 16
            ) {
                ForEach(icons) { icon in
                    VStack(spacing: 4) {
                        
                        Image(icon.iconName)
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                        Text(icon.name)
                            .multilineTextAlignment(.center)
                    }
                    .onTapGesture(count: 1) {
                        choosedIconName = icon.iconName
                        isPresented = false
                    }
                }
            }.padding()
        }
        .frame(maxHeight: 200)
    }
}
