//
//  ContentView.swift
//  RoomDesignerDemo
//
//  Created by 格林 on 2025/10/24.
//

import SwiftUI
import RealityKit

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 20) {
            Text("房间设计器")
                .font(.largeTitle)

            // 显示当前状态
            Text(appState.isImmersive ? "沉浸模式" : "窗口模式")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppState())
}
