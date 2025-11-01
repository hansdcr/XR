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

            // 错误信息显示
            if appState.errorState != .none {
                errorView
            }

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

                    // 可视化模式选择器
                    Picker("可视化模式", selection: Binding(
                        get: { appState.visualizationMode },
                        set: { appState.setVisualizationMode($0) }
                    )) {
                        Text("无").tag(VisualizationMode.none)
                        Text("墙面").tag(VisualizationMode.walls)
                        Text("遮挡").tag(VisualizationMode.occlusion)
                    }
                    .pickerStyle(.segmented)

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

    @ViewBuilder
    private var errorView: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.red)

            switch appState.errorState {
            case .none:
                EmptyView()
            case .notSupported:
                Text("设备不支持房间跟踪")
            case .notAuthorized:
                Text("需要世界感知权限")
            case .sessionError(let message):
                Text("会话错误: \(message)")
            }
        }
        .padding()
        .background(.red.opacity(0.1))
        .cornerRadius(10)
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppState())
}
