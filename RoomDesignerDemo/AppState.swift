//
//  AppState.swift
//  RoomDesignerDemo
//
//  Created by Claude on 2025/10/27.
//

import Foundation
import Observation
import RealityKit
import UIKit

@Observable
@MainActor
class AppState {
    // 是否在沉浸式空间中
    var isImmersive = false

    // 3D 内容的根实体
    let contentRoot = Entity()

    init() {
        print("--->AppState initialized")
        setupContentEntity()
    }

    func setupContentEntity() {
        contentRoot.name = "ContentRoot"
        createTestSphere()
        print("--->Content entity setup complete")
    }

    private func createTestSphere() {
        // 创建球体网格
        let mesh = MeshResource.generateSphere(radius: 0.1)

        // 创建材质（绿色）
        let material = SimpleMaterial(
            color: .green,
            roughness: 0.2,
            isMetallic: true
        )

        // 创建模型实体
        let sphere = ModelEntity(
            mesh: mesh,
            materials: [material]
        )

        // 设置位置（在用户前方1米）
        sphere.position = [0, 1.5, -1]
        sphere.name = "TestSphere"

        // 添加到根实体
        contentRoot.addChild(sphere)

        print("Test sphere created at position: \(sphere.position)")
    }
}
