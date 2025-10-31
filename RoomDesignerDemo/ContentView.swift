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
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        VStack(spacing: 20) {
            Text("房间设计器")
                .font(.largeTitle)

            if !appState.isImmersive {
                Button("进入沉浸式空间") {
                    Task {
                        await openImmersiveSpaceAction()
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                VStack(spacing: 15) {
                    Button(appState.showPreviewSphere ? "取消放置" : "添加球体") {
                        appState.showPreviewSphere.toggle()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("删除所有球体") {
                        appState.removeAllSpheres()
                    }
                    .buttonStyle(.bordered)
                    .disabled(appState.sphereEntities.isEmpty)

                    Button("退出沉浸式空间") {
                        Task {
                            await closeImmersiveSpaceAction()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
    }

    private func openImmersiveSpaceAction() async {
        await openImmersiveSpace(id: "ImmersiveSpace")
        appState.isImmersive = true
    }

    private func closeImmersiveSpaceAction() async {
        await dismissImmersiveSpace()
        appState.isImmersive = false
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppState())
}
