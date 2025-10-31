//
//  Extensions.swift
//  RoomDesignerDemo
//
//  Created by Claude on 2025/10/31.
//

import ARKit
import RealityKit

extension MeshAnchor.Geometry {
    @MainActor
    func asMeshResource() -> MeshResource? {
        // 获取顶点数据
        let vertices = self.vertices.asSIMD3(ofType: Float.self)

        // 获取面索引
        let faces = self.faces.asIndexArray()

        // 创建网格描述符
        var descriptor = MeshDescriptor()
        descriptor.positions = .init(vertices)
        descriptor.primitives = .triangles(faces)

        // 生成网格资源
        do {
            let mesh = try MeshResource.generate(from: [descriptor])
            return mesh
        } catch {
            print("--->Failed to generate mesh: \(error)")
            return nil
        }
    }
}

// 辅助扩展
extension GeometrySource {
    func asSIMD3<T>(ofType: T.Type) -> [SIMD3<T>] {
        var result: [SIMD3<T>] = []
        for i in 0..<count {
            let data = buffer.contents() + offset + (stride * i)
            let value = data.assumingMemoryBound(to: SIMD3<T>.self).pointee
            result.append(value)
        }
        return result
    }
}

extension GeometryElement {
    func asIndexArray() -> [UInt32] {
        var result: [UInt32] = []

        // ARKit 的墙面几何通常使用三角形，每个三角形有3个索引
        let indexCount = count * 3

        for i in 0..<indexCount {
            let data = buffer.contents() + (i * bytesPerIndex)
            let index = data.assumingMemoryBound(to: UInt32.self).pointee
            result.append(index)
        }
        return result
    }
}
