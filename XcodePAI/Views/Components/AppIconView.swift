//
//  AppIconView.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/13.
//

import SwiftUI

struct AppIconView: View {
    var body: some View {
        if let image = NSImage(named: "AppIcon") {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            EmptyView()
        }
    }
}
