//
//  ImmersiveView.swift
//  RoomDesignerDemo
//
//  Created by Claude on 2025/10/27.
//

import SwiftUI
import RealityKit

struct ImmersiveView: View {
    @Environment(AppState.self) private var appState
    @State private var previewSphere: ModelEntity?

    var body: some View {
        RealityView { content in
            content.add(appState.contentRoot)

            // 创建预览球体
            let preview = createPreviewSphere()
            previewSphere = preview

            // 创建头部锚点
            let headAnchor = AnchorEntity(.head)
            headAnchor.addChild(preview)
            content.add(headAnchor)

            print("--->Root entity added to scene")
            print("--->Preview sphere created")
        }
        .task {
            await appState.initializeARKit()
        }
        .onChange(of: appState.showPreviewSphere) { _, newValue in
            previewSphere?.isEnabled = newValue
            print("--->Preview sphere visible: \(newValue)")
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { event in
                    handleTap(event)
                }
        )
    }

    private func handleTap(_ event: EntityTargetValue<SpatialTapGesture.Value>) {
        guard let previewSphere,
              event.entity == previewSphere else {
            return
        }

        // 获取预览球体的世界位置
        let worldPosition = previewSphere.position(relativeTo: nil)

        // 在该位置创建球体
        appState.addSphereAtPosition(worldPosition)

        // 隐藏预览球体
        appState.showPreviewSphere = false
    }

    private func createPreviewSphere() -> ModelEntity {
        let mesh = MeshResource.generateSphere(radius: 0.1)

        // 半透明灰色材质
        var material = SimpleMaterial()
        material.color = .init(
            tint: .gray.withAlphaComponent(0.5)
        )

        let sphere = ModelEntity(mesh: mesh, materials: [material])
        sphere.position = [0, 0, -1]  // 头部前方1米
        sphere.name = "PreviewSphere"
        sphere.isEnabled = false  // 初始隐藏

        // 添加碰撞形状
        sphere.generateCollisionShapes(recursive: false)

        // 添加输入目标组件（允许间接输入：视线+手势）
        sphere.components.set(
            InputTargetComponent(allowedInputTypes: [.indirect])
        )

        print("--->Preview sphere collision enabled")
        return sphere
    }
}
