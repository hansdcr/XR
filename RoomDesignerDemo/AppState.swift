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

        // 创建多个球体
        createColoredSphere(color: .red, position: [-0.3, 1.5, -1])
        createColoredSphere(color: .green, position: [0, 1.5, -1])
        createColoredSphere(color: .blue, position: [0.3, 1.5, -1])

        print("--->Content entity setup complete")
    }

    private func createColoredSphere(
        color: UIColor,
        position: SIMD3<Float>
    ) {
        let mesh = MeshResource.generateSphere(radius: 0.1)
        let material = SimpleMaterial(
            color: color,
            roughness: 0.2,
            isMetallic: true
        )

        let sphere = ModelEntity(mesh: mesh, materials: [material])
        sphere.position = position
        sphere.name = "Sphere_\(color.description)"

        contentRoot.addChild(sphere)
        print("Sphere created at \(position)")
    }
}
