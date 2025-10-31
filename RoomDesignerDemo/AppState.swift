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
import ARKit

@Observable
@MainActor
class AppState {
    // 是否在沉浸式空间中
    var isImmersive = false

    // 是否显示预览球体
    var showPreviewSphere = false

    // 3D 内容的根实体
    let contentRoot = Entity()

    // 存储所有球体实体
    private(set) var sphereEntities: [UUID: ModelEntity] = [:]

    // ARKit session
    private let session = ARKitSession()
    private let worldTracking = WorldTrackingProvider()
    private let roomTracking = RoomTrackingProvider()

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

        let id = UUID()
        sphere.name = "Sphere_\(id)"

        contentRoot.addChild(sphere)
        sphereEntities[id] = sphere

        print("Sphere \(id) created at \(position)")
    }

    func initializeARKit() async {
        print("--->ARKit initialization started")

        do {
            // 同时运行世界跟踪和房间跟踪
            try await session.run([worldTracking, roomTracking])
            print("--->ARKit session started with room tracking")
        } catch {
            print("--->ARKit session failed: \(error)")
        }
    }

    func addSphereAtPosition(_ position: SIMD3<Float>) {
        let mesh = MeshResource.generateSphere(radius: 0.1)
        let material = SimpleMaterial(
            color: .blue,
            roughness: 0.2,
            isMetallic: true
        )

        let sphere = ModelEntity(mesh: mesh, materials: [material])
        sphere.position = position

        let id = UUID()
        sphere.name = "Sphere_\(id)"

        contentRoot.addChild(sphere)
        sphereEntities[id] = sphere

        print("--->Sphere placed at \(position)")
    }

    func removeAllSpheres() {
        for (id, sphere) in sphereEntities {
            sphere.removeFromParent()
            print("--->Sphere \(id) removed")
        }
        sphereEntities.removeAll()
        print("--->All spheres removed")
    }
}
