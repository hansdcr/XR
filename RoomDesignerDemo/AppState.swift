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
    let roomRoot = Entity()
    let wallRoot = Entity()

    // 存储所有球体实体
    private(set) var sphereEntities: [UUID: ModelEntity] = [:]

    // 存储房间锚点
    private var roomAnchors: [UUID: RoomAnchor] = [:]

    // 存储墙面实体
    private var wallEntities: [String: ModelEntity] = [:]

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
        roomRoot.name = "RoomRoot"
        wallRoot.name = "WallRoot"

        // 将子实体添加到 contentRoot
        contentRoot.addChild(roomRoot)
        contentRoot.addChild(wallRoot)

        // 创建多个球体
        createColoredSphere(color: .red, position: [-0.3, 1.5, -1])
        createColoredSphere(color: .green, position: [0, 1.5, -1])
        createColoredSphere(color: .blue, position: [0.3, 1.5, -1])

        print("--->Content entities setup complete")
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

            // 启动房间更新监听
            await processRoomUpdates()
        } catch {
            print("--->ARKit session failed: \(error)")
        }
    }

    private func processRoomUpdates() async {
        for await update in roomTracking.anchorUpdates {
            switch update.event {
            case .added:
                handleRoomAdded(update.anchor)
            case .updated:
                handleRoomUpdated(update.anchor)
            case .removed:
                handleRoomRemoved(update.anchor)
            }
        }
    }

    private func handleRoomAdded(_ anchor: RoomAnchor) {
        roomAnchors[anchor.id] = anchor
        print("--->Room added: \(anchor.id)")
    }

    private func handleRoomUpdated(_ anchor: RoomAnchor) {
        roomAnchors[anchor.id] = anchor
        updateSphereColors()  // 房间更新时重新计算颜色
//        print("--->Room updated: \(anchor.id)")
    }

    private func handleRoomRemoved(_ anchor: RoomAnchor) {
        roomAnchors.removeValue(forKey: anchor.id)
        print("--->Room removed: \(anchor.id)")
    }

    private func isSphereInCurrentRoom(position: SIMD3<Float>) -> Bool {
        // 获取当前房间锚点
        guard let currentRoom = roomTracking.currentRoomAnchor else {
            print("--->No current room")
            return false
        }

        // 检查位置是否在房间内
        let isInRoom = currentRoom.contains(position)
        print("--->Position \(position) in room: \(isInRoom)")
        return isInRoom
    }

    func addSphereAtPosition(_ position: SIMD3<Float>) {
        let mesh = MeshResource.generateSphere(radius: 0.1)

        // 根据是否在房间内选择颜色
        let isInRoom = isSphereInCurrentRoom(position: position)
        let color: UIColor = isInRoom ? .green : .red

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

        print("--->Sphere placed at \(position), color: \(isInRoom ? "green" : "red")")
    }

    func removeAllSpheres() {
        for (id, sphere) in sphereEntities {
            sphere.removeFromParent()
            print("--->Sphere \(id) removed")
        }
        sphereEntities.removeAll()
        print("--->All spheres removed")
    }

    private func updateSphereColors() {
        for (_, sphere) in sphereEntities {
            let isInRoom = isSphereInCurrentRoom(position: sphere.position)
            let color: UIColor = isInRoom ? .green : .red

            let material = SimpleMaterial(
                color: color,
                roughness: 0.2,
                isMetallic: true
            )

            sphere.model?.materials = [material]
        }
        print("--->Sphere colors updated")
    }
}
