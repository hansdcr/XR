//
//  ContentView.swift
//  RoomDesignerDemo
//
//  Created by 格林 on 2025/10/24.
//

import SwiftUI
import RealityKit

struct ContentView: View {

    var body: some View {
        VStack(spacing: 20) {
            Text("房间设计器")
                .font(.largeTitle)

            Text("准备开始")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
