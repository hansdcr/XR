//
//  RoomDesignerDemoApp.swift
//  RoomDesignerDemo
//
//  Created by 格林 on 2025/10/24.
//

import SwiftUI

@main
struct RoomDesignerDemoApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }

        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
                .environment(appState)
        }
    }
}
