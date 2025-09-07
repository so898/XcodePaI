//
//  AboutSettingSectionView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/9/7.
//

import Foundation
import SwiftUI

struct AboutSettingSectionView: View {
    @State var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 10) {
                let appImage = if let nsImage = NSImage(named: "AppIcon") {
                    Image(nsImage: nsImage)
                } else {
                    Image(systemName: "app")
                }
                appImage
                    .resizable()
                    .frame(width: 110, height: 110)
                HStack {
                    Spacer()
                    Text(Bundle.main.object(forInfoDictionaryKey: "HOST_APP_NAME") as? String ?? "XcodePaI")
                        .font(.title)
                    Text("(\(appVersion ?? ""))")
                        .font(.title)
                    Spacer()
                }
            }
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 18) {
                
                GridRow(alignment: .center) {
                    Text("Check Update")
                    Button("Check") {
                        
                    }
                }
            }
        }
        .navigationTitle("About")
    }
}
