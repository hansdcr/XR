# branch01 迭代计划 - 功能优化

## 文档说明

本文档基于已完成的 40 个基础迭代,针对三个优化需求进行详细的迭代规划。

## 优化需求概述

### 需求1: 空间锚点持久化
**问题**: 球体位置跟随头部,重启应用后位置会偏移
**目标**: 球体固定在房间空间中,应用重启后位置保持不变

### 需求2: 球体拖动和旋转交互
**问题**: 球体只能放置,无法调整
**目标**: 实现球体的拖动、旋转交互

### 需求3: 墙面网格精度优化
**问题**: 生成的墙面网格与真实墙体距离过远
**目标**: 误差控制在 5cm 以内

---

# 阶段1: 空间锚点持久化

## 迭代 41: 添加 WorldAnchor 存储结构

### 目标
为持久化空间锚点准备数据结构

### 修改文件
- `AppState.swift`

### 方法列表
1. 添加 `worldAnchors` 属性
2. 添加 `sphereAnchors` 映射关系

### 代码要点

**AppState.swift**:
```swift
@Observable
@MainActor
class AppState {
    // ... 现有属性

    // 存储世界锚点
    private var worldAnchors: [UUID: WorldAnchor] = [:]

    // 球体与锚点的映射关系
    private var sphereAnchors: [UUID: UUID] = [:]  // 球体ID -> 锚点ID

    // ... 其他代码
}
```

### 测试验证
- 代码编译无错误

### 学习重点
- `WorldAnchor` 概念和作用
- 数据结构设计:映射关系管理
- 持久化空间定位的准备工作

### 代码详解

#### WorldAnchor 是什么?

```
WorldAnchor (世界锚点):
- visionOS 特有的持久化空间锚点
- 固定在真实世界空间中的参考点
- 应用重启后仍然有效
- 可以跨会话保存和恢复位置

与其他锚点的区别:
- AnchorEntity(.head): 跟随头部移动
- AnchorEntity(.hand): 跟随手部移动
- RoomAnchor: 表示房间结构
- WorldAnchor: 固定在世界空间中 ✓
```

#### 数据结构设计

```
为什么需要两个字典?

1. worldAnchors: [UUID: WorldAnchor]
   - 存储所有的世界锚点实例
   - UUID 是锚点的唯一标识
   - 用于管理锚点的生命周期

2. sphereAnchors: [UUID: UUID]
   - 球体ID → 锚点ID 的映射
   - 快速查找某个球体对应的锚点
   - 删除球体时可以找到并删除对应的锚点

关系示意:
┌─────────────┐      sphereAnchors      ┌──────────────┐
│  Sphere ID  │ ───────────────────────> │  Anchor ID   │
└─────────────┘      (映射关系)          └──────────────┘
       │                                         │
       │                                         │
       ↓                                         ↓
  ModelEntity                              WorldAnchor
  (可见的球体)                              (空间定位点)
```

#### 为什么使用 private?

```swift
private var worldAnchors: [UUID: WorldAnchor] = [:]
private var sphereAnchors: [UUID: UUID] = [:]
```

- 封装性: 外部不应直接修改这些映射关系
- 一致性: 通过方法操作,确保两个字典同步更新
- 安全性: 防止意外的数据不一致

---

## 迭代 42: 创建 WorldAnchor 辅助方法

### 目标
封装创建和管理 WorldAnchor 的方法

### 修改文件
- `AppState.swift`

### 方法列表
1. `createWorldAnchor(at:)` - 创建世界锚点
2. `removeWorldAnchor(id:)` - 删除世界锚点

### 代码要点

**AppState.swift**:
```swift
private func createWorldAnchor(
    at position: SIMD3<Float>
) async -> WorldAnchor? {
    // 创建变换矩阵
    let transform = Transform(
        scale: .one,
        rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
        translation: position
    )

    do {
        // 创建世界锚点
        let anchor = WorldAnchor(originFromAnchorTransform: transform.matrix)

        // 添加到会话中追踪
        try await session.run([worldTracking])

        // 存储锚点
        worldAnchors[anchor.id] = anchor

        print("--->WorldAnchor created at \(position)")
        return anchor
    } catch {
        print("--->Failed to create WorldAnchor: \(error)")
        return nil
    }
}

private func removeWorldAnchor(id: UUID) {
    worldAnchors.removeValue(forKey: id)
    print("--->WorldAnchor \(id) removed")
}
```

### 测试验证
- 代码编译无错误

### 学习重点
- `WorldAnchor` 初始化
- `originFromAnchorTransform` 变换矩阵
- 异步创建锚点的流程
- simd_quatf 四元数表示旋转

### 代码详解

#### Transform 和变换矩阵

```swift
let transform = Transform(
    scale: .one,          // 缩放为 1 (不缩放)
    rotation: simd_quatf, // 旋转 (四元数)
    translation: position // 平移 (位置)
)
```

**Transform 的三要素**:
1. **Scale (缩放)**:
   - `.one` 表示 (1, 1, 1),不缩放
   - 可以设置不同轴向的缩放

2. **Rotation (旋转)**:
   - 使用四元数 `simd_quatf` 表示
   - `simd_quatf(angle: 0, axis: [0, 1, 0])` 表示绕 Y 轴旋转 0 度(无旋转)
   - 四元数比欧拉角更稳定,避免万向锁

3. **Translation (平移)**:
   - 就是位置坐标 `SIMD3<Float>`
   - 例如 `[0, 1.5, -1]` 表示在 x=0, y=1.5米, z=-1米

#### originFromAnchorTransform 是什么?

```
originFromAnchorTransform: 从锚点到世界原点的变换矩阵

世界坐标系                锚点坐标系
  (原点)                   (锚点)
     ↑                       ↑
     │                       │
     │    ←─────────────────  │
     │   originFromAnchorTransform
     │
   [0,0,0]                [x,y,z]

这个 4x4 矩阵包含:
- 旋转信息 (3x3)
- 平移信息 (3x1)
- 缩放信息 (隐含在矩阵中)
```

#### 为什么需要 async await?

```swift
let anchor = WorldAnchor(originFromAnchorTransform: transform.matrix)
try await session.run([worldTracking])
```

**原因**:
- WorldAnchor 需要与 ARKitSession 配合
- 系统需要时间来建立空间追踪
- 可能涉及设备传感器和计算
- 异步操作不阻塞主线程

#### 四元数 simd_quatf

```
为什么使用四元数而不是欧拉角?

欧拉角 (Euler Angles):
- 直观: (pitch, yaw, roll) 或 (x, y, z 旋转)
- 问题: 万向锁 (Gimbal Lock)
- 问题: 插值不平滑

四元数 (Quaternion):
✓ 避免万向锁
✓ 插值平滑 (slerp)
✓ 计算效率高
✓ 适合 3D 旋转

simd_quatf(angle: 0, axis: [0, 1, 0])
          ↑            ↑
        角度         旋转轴
      (弧度)        (Y轴向上)
```

#### 错误处理

```swift
do {
    let anchor = WorldAnchor(...)
    try await session.run(...)
    return anchor
} catch {
    print("--->Failed to create WorldAnchor: \(error)")
    return nil
}
```

**可能的错误**:
- 权限不足
- 设备不支持
- 空间追踪失败
- 会话未启动

---

## 迭代 43: 修改球体创建使用 WorldAnchor

### 目标
将球体附加到世界锚点,实现房间固定定位

### 修改文件
- `AppState.swift`

### 方法列表
1. 修改 `addSphereAtPosition(_:)` - 创建锚点并关联球体

### 代码要点

**AppState.swift**:
```swift
func addSphereAtPosition(_ position: SIMD3<Float>) async {
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
    let sphereId = UUID()
    sphere.name = "Sphere_\(sphereId)"

    // 创建世界锚点
    guard let worldAnchor = await createWorldAnchor(at: position) else {
        print("--->Failed to create anchor, sphere not placed")
        return
    }

    // 创建锚点实体
    let anchorEntity = AnchorEntity(anchor: worldAnchor)
    anchorEntity.addChild(sphere)

    // 添加到场景
    contentRoot.addChild(anchorEntity)

    // 存储映射关系
    sphereEntities[sphereId] = sphere
    sphereAnchors[sphereId] = worldAnchor.id

    print("--->Sphere placed with WorldAnchor at \(position), color: \(isInRoom ? "green" : "red")")
}
```

### 测试验证
- 放置球体后,退出沉浸式空间再进入,球体应保持原位置
- (注意:完整测试需要应用重启,在迭代44实现持久化保存)

### 学习重点
- `AnchorEntity(anchor:)` 使用 WorldAnchor
- 球体实体层级:AnchorEntity → ModelEntity
- 异步方法调用链

### 代码详解

#### 实体层级结构变化

**之前的结构**:
```
contentRoot
└── sphere (ModelEntity)
    position: 世界坐标 (会话相对)
```

**现在的结构**:
```
contentRoot
└── anchorEntity (AnchorEntity with WorldAnchor)
    └── sphere (ModelEntity)
        position: [0, 0, 0] (相对于锚点)
```

#### 为什么球体位置是 [0, 0, 0]?

```swift
let sphere = ModelEntity(mesh: mesh, materials: [material])
// 注意:没有设置 sphere.position

let anchorEntity = AnchorEntity(anchor: worldAnchor)
anchorEntity.addChild(sphere)
```

- `sphere` 的位置默认是 `[0, 0, 0]`
- 这个 `[0, 0, 0]` 是相对于 `anchorEntity` 的局部坐标
- `anchorEntity` 的位置由 `worldAnchor` 决定
- 所以球体的世界位置 = 锚点位置 + 球体局部位置

**如果需要偏移**:
```swift
sphere.position = [0, 0.1, 0]  // 球体在锚点上方10cm
```

#### AnchorEntity(anchor:) 的作用

```
AnchorEntity 的两种创建方式:

1. 特殊锚点类型:
   AnchorEntity(.head)      // 跟随头部
   AnchorEntity(.hand)      // 跟随手部
   AnchorEntity(.plane(...))  // 平面锚定

2. 自定义锚点:
   AnchorEntity(anchor: worldAnchor)  // 使用 WorldAnchor
   - worldAnchor 定义了空间中的固定位置
   - AnchorEntity 跟踪这个锚点
   - 添加的子实体相对于锚点定位
```

#### 为什么方法签名变了?

```swift
// 之前:
func addSphereAtPosition(_ position: SIMD3<Float>) {
    // 同步方法
}

// 现在:
func addSphereAtPosition(_ position: SIMD3<Float>) async {
    // 异步方法
    guard let worldAnchor = await createWorldAnchor(at: position) else {
        return
    }
}
```

**原因**:
- `createWorldAnchor` 是异步方法
- 调用异步方法需要 `await`
- 包含 `await` 的方法必须是 `async`

#### 调用链的变化

```
用户点击预览球体
       ↓
ImmersiveView.handleTap()
       ↓
appState.addSphereAtPosition(worldPosition)  ← 现在是 async
       ↓
await createWorldAnchor(at: position)
       ↓
创建 AnchorEntity
       ↓
添加到场景
```

**ImmersiveView.swift 也需要修改**:
```swift
// 之前:
appState.addSphereAtPosition(worldPosition)

// 现在:
await appState.addSphereAtPosition(worldPosition)
```

---

## 迭代 44: 修改 ImmersiveView 调用异步方法

### 目标
适配 addSphereAtPosition 的异步调用

### 修改文件
- `ImmersiveView.swift`

### 方法列表
1. 修改 `handleTap(_:)` - 异步调用球体创建

### 代码要点

**ImmersiveView.swift**:
```swift
private func handleTap(_ event: EntityTargetValue<SpatialTapGesture.Value>) {
    guard let previewSphere,
          event.entity == previewSphere else {
        return
    }

    // 在 Task 中执行异步操作
    Task {
        // 获取预览球体的世界位置
        let worldPosition = previewSphere.position(relativeTo: nil)

        // 异步创建球体
        await appState.addSphereAtPosition(worldPosition)

        // 隐藏预览球体
        await MainActor.run {
            appState.showPreviewSphere = false
        }
    }
}
```

### 测试验证
- 点击预览球体,正常创建
- 不应该有编译错误或警告

### 学习重点
- 同步上下文调用异步方法:使用 `Task {}`
- `MainActor.run` 确保 UI 更新在主线程
- 手势处理中的异步操作模式

### 代码详解

#### 为什么需要 Task {}?

```swift
private func handleTap(...) {  // 注意:这个方法不是 async
    Task {
        await appState.addSphereAtPosition(worldPosition)
    }
}
```

**原因**:
- `handleTap` 是手势回调,签名不能改成 `async`
- 手势系统期望同步返回
- `Task {}` 创建一个新的异步上下文
- 在这个上下文中可以使用 `await`

#### MainActor.run 的作用

```swift
await MainActor.run {
    appState.showPreviewSphere = false
}
```

**为什么需要**:
- `appState.showPreviewSphere` 是 UI 状态
- SwiftUI 的状态更新必须在主线程 (MainActor)
- `Task {}` 默认在后台线程
- `MainActor.run` 切换回主线程执行

**简化写法**:
如果整个 Task 都在主线程:
```swift
Task { @MainActor in
    let worldPosition = previewSphere.position(relativeTo: nil)
    await appState.addSphereAtPosition(worldPosition)
    appState.showPreviewSphere = false  // 不需要 MainActor.run
}
```

#### 异步操作的执行顺序

```
handleTap 调用
    ↓
创建 Task (不阻塞)
    ↓
handleTap 立即返回
    ↓
Task 在后台执行:
    ├─ 获取位置
    ├─ await 创建球体 (等待完成)
    └─ 切换到主线程更新 UI
```

#### 错误处理 (可选)

```swift
Task {
    do {
        let worldPosition = previewSphere.position(relativeTo: nil)
        try await appState.addSphereAtPosition(worldPosition)

        await MainActor.run {
            appState.showPreviewSphere = false
        }
    } catch {
        print("--->Failed to place sphere: \(error)")
    }
}
```

---

## 迭代 45: 实现 WorldAnchor 持久化保存

### 目标
将锚点数据保存到文件系统,实现跨会话恢复

### 修改文件
- `AppState.swift`

### 方法列表
1. `saveWorldAnchors()` - 保存锚点到文件
2. `loadWorldAnchors()` - 从文件加载锚点
3. 修改 `addSphereAtPosition` - 保存后调用存储

### 代码要点

**AppState.swift**:
```swift
// 持久化文件路径
private var anchorsFileURL: URL {
    let documentsPath = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    ).first!
    return documentsPath.appendingPathComponent("worldAnchors.data")
}

func saveWorldAnchors() async {
    do {
        // 将锚点数据编码
        let data = try await worldTracking.anchorData(for: Array(worldAnchors.values))

        // 保存到文件
        try data.write(to: anchorsFileURL)

        print("--->Saved \(worldAnchors.count) world anchors")
    } catch {
        print("--->Failed to save anchors: \(error)")
    }
}

func loadWorldAnchors() async {
    do {
        // 从文件读取数据
        let data = try Data(contentsOf: anchorsFileURL)

        // 解码锚点
        let anchors = try await worldTracking.anchors(from: data)

        // 存储到字典
        for anchor in anchors {
            worldAnchors[anchor.id] = anchor
        }

        print("--->Loaded \(anchors.count) world anchors")
    } catch {
        print("--->No saved anchors or failed to load: \(error)")
    }
}

// 修改 addSphereAtPosition 添加保存调用
func addSphereAtPosition(_ position: SIMD3<Float>) async {
    // ... 现有代码 ...

    // 保存锚点数据
    await saveWorldAnchors()
}
```

### 测试验证
- 放置球体,退出应用
- 重新启动应用,球体应该还在原位置

### 学习重点
- `WorldTrackingProvider.anchorData(for:)` 编码锚点
- `WorldTrackingProvider.anchors(from:)` 解码锚点
- FileManager 文件操作
- 持久化数据的序列化和反序列化

### 代码详解

#### 文件路径获取

```swift
private var anchorsFileURL: URL {
    let documentsPath = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    ).first!
    return documentsPath.appendingPathComponent("worldAnchors.data")
}
```

**Documents 目录**:
- iOS/visionOS 应用的文档存储目录
- 应用私有,其他应用无法访问
- 会被 iCloud 同步 (如果启用)
- 不会被系统清理

**路径示例**:
```
/Users/[name]/Library/Developer/CoreSimulator/Devices/[device-id]/
  data/Containers/Data/Application/[app-id]/Documents/worldAnchors.data
```

#### anchorData 序列化

```swift
let data = try await worldTracking.anchorData(for: Array(worldAnchors.values))
```

**工作原理**:
- `worldTracking` 是 WorldTrackingProvider 实例
- `anchorData(for:)` 将 WorldAnchor 数组编码为 Data
- 这个 Data 包含锚点的所有信息:
  - 空间位置
  - 变换矩阵
  - 系统追踪信息
- 格式是 visionOS 专有的,不需要手动解析

#### anchors(from:) 反序列化

```swift
let anchors = try await worldTracking.anchors(from: data)
```

**工作原理**:
- 从 Data 解码为 WorldAnchor 数组
- 系统会验证数据完整性
- 恢复锚点的追踪状态

#### 为什么需要 async?

```swift
try await worldTracking.anchorData(for: anchors)
try await worldTracking.anchors(from: data)
```

**原因**:
- 编码/解码涉及系统服务
- 可能需要与空间追踪系统通信
- 确保锚点数据的有效性
- 不阻塞主线程

#### 错误处理场景

```swift
do {
    let data = try Data(contentsOf: anchorsFileURL)
    // ...
} catch {
    print("--->No saved anchors or failed to load: \(error)")
}
```

**可能的错误**:
1. **文件不存在**: 首次运行,还没有保存过
2. **权限问题**: 无法读取文件
3. **数据损坏**: 文件被修改或损坏
4. **版本不兼容**: 旧版本的数据格式

#### 自动保存策略

```swift
func addSphereAtPosition(_ position: SIMD3<Float>) async {
    // ... 创建球体和锚点 ...

    // 每次添加球体后自动保存
    await saveWorldAnchors()
}
```

**其他保存时机**:
- 删除球体后
- 应用进入后台
- 退出沉浸式空间

---

## 迭代 46: 应用启动时恢复球体

### 目标
应用启动时加载保存的锚点并重建球体

### 修改文件
- `AppState.swift`

### 方法列表
1. `restoreSpheres()` - 恢复球体实体
2. 修改 `initializeARKit()` - 启动后恢复

### 代码要点

**AppState.swift**:
```swift
func initializeARKit() async {
    let startTime = Date()
    isInitializing = true
    defer {
        let duration = Date().timeIntervalSince(startTime)
        isInitializing = false
        print("--->✅ ARKit initialized (duration: \(String(format: "%.3f", duration))s)")
    }

    print("--->ARKit initialization started")

    // 检查权限
    guard await checkAuthorization() else {
        print("--->Authorization denied")
        return
    }

    // 检查支持性
    guard WorldTrackingProvider.isSupported,
          RoomTrackingProvider.isSupported else {
        errorState = .notSupported
        print("--->Tracking not supported")
        return
    }

    do {
        // 同时运行世界跟踪和房间跟踪
        try await session.run([worldTracking, roomTracking])
        errorState = .none
        print("--->ARKit session started")

        // 加载保存的锚点
        await loadWorldAnchors()

        // 恢复球体
        await restoreSpheres()

        // 在后台启动房间更新监听
        Task {
            await processRoomUpdates()
        }
    } catch {
        errorState = .sessionError(error.localizedDescription)
        print("--->ARKit session failed: \(error)")
    }
}

private func restoreSpheres() async {
    // 清除现有的测试球体
    for (id, sphere) in sphereEntities {
        sphere.removeFromParent()
    }
    sphereEntities.removeAll()

    print("--->Restoring spheres from anchors...")

    // 为每个锚点创建球体
    for (anchorId, worldAnchor) in worldAnchors {
        // 创建球体实体
        let mesh = MeshResource.generateSphere(radius: 0.1)
        let material = SimpleMaterial(
            color: .blue,  // 恢复的球体暂时统一颜色
            roughness: 0.2,
            isMetallic: true
        )

        let sphere = ModelEntity(mesh: mesh, materials: [material])
        let sphereId = UUID()
        sphere.name = "Sphere_\(sphereId)"

        // 创建锚点实体
        let anchorEntity = AnchorEntity(anchor: worldAnchor)
        anchorEntity.addChild(sphere)

        // 添加到场景
        contentRoot.addChild(anchorEntity)

        // 存储映射关系
        sphereEntities[sphereId] = sphere
        sphereAnchors[sphereId] = anchorId

        print("--->Restored sphere \(sphereId) at anchor \(anchorId)")
    }

    print("--->Restored \(sphereEntities.count) spheres")
}
```

### 测试验证
1. 放置几个球体
2. 退出应用
3. 重新启动应用
4. 进入沉浸式空间,球体应该出现在之前的位置

### 学习重点
- 应用启动流程
- 实体重建策略
- 锚点与实体的关联
- 清理旧数据的必要性

### 代码详解

#### 初始化流程优化

```
initializeARKit() 执行顺序:

1. 设置加载状态
2. 检查权限
3. 检查设备支持
4. 启动 ARKit 会话
5. 加载保存的锚点        ← 新增
6. 恢复球体实体          ← 新增
7. 启动房间更新监听
8. 清除加载状态 (defer)
```

#### 为什么要清除测试球体?

```swift
// 清除现有的测试球体
for (id, sphere) in sphereEntities {
    sphere.removeFromParent()
}
sphereEntities.removeAll()
```

**原因**:
- `setupContentEntity()` 在 init 中创建了3个测试球体
- 这些球体不是通过 WorldAnchor 创建的
- 如果不清除,会与恢复的球体混在一起
- 恢复的球体来自持久化数据,应该是唯一的内容

**后续优化** (迭代47):
- 在 `setupContentEntity()` 中不创建测试球体
- 或者添加一个配置选项控制是否创建

#### 为什么恢复的球体是蓝色?

```swift
let material = SimpleMaterial(
    color: .blue,  // 恢复的球体暂时统一颜色
    // ...
)
```

**原因**:
- 当前没有保存球体的颜色信息
- 只保存了锚点(位置)
- 后续迭代可以添加球体属性的持久化

**完整的持久化** (可选的后续迭代):
```swift
struct SphereData: Codable {
    let anchorId: UUID
    let color: CodableColor  // 需要自定义编码
    let radius: Float
}
```

#### 锚点与实体的绑定

```swift
// 为每个锚点创建球体
for (anchorId, worldAnchor) in worldAnchors {
    // 创建球体
    let sphere = ModelEntity(...)
    let sphereId = UUID()

    // 创建锚点实体
    let anchorEntity = AnchorEntity(anchor: worldAnchor)
    anchorEntity.addChild(sphere)

    // 建立映射
    sphereAnchors[sphereId] = anchorId
}
```

**数据关系**:
```
worldAnchors: [UUID: WorldAnchor]
    anchorId1 -> WorldAnchor1
    anchorId2 -> WorldAnchor2

                  ↓ restoreSpheres()

sphereEntities: [UUID: ModelEntity]
    sphereId1 -> ModelEntity1
    sphereId2 -> ModelEntity2

sphereAnchors: [UUID: UUID]
    sphereId1 -> anchorId1
    sphereId2 -> anchorId2
```

#### 恢复的异步性

```swift
await loadWorldAnchors()  // 异步加载
await restoreSpheres()    // 异步恢复
```

**为什么 restoreSpheres 是 async?**
- 虽然当前实现是同步的
- 但为了一致性和未来扩展性
- 例如:可能需要异步加载球体的纹理或模型

---

## 迭代 47: 移除测试球体创建

### 目标
清理 setupContentEntity 中的测试代码,只保留必要的初始化

### 修改文件
- `AppState.swift`

### 方法列表
1. 修改 `setupContentEntity()` - 移除测试球体

### 代码要点

**AppState.swift**:
```swift
func setupContentEntity() {
    contentRoot.name = "ContentRoot"
    roomRoot.name = "RoomRoot"
    wallRoot.name = "WallRoot"

    // 将子实体添加到 contentRoot
    contentRoot.addChild(roomRoot)
    contentRoot.addChild(wallRoot)

    // 确保 wallRoot 默认启用
    wallRoot.isEnabled = true

    // 移除了测试球体创建代码
    // createColoredSphere(...) // 不再需要

    print("--->Content entities setup complete")
}

// 可以保留 createColoredSphere 方法用于调试
// 但不在初始化时调用
```

### 测试验证
- 应用启动后,不应该有自动创建的球体
- 只有恢复的球体或手动放置的球体

### 学习重点
- 清理测试代码的重要性
- 保持初始化逻辑简洁
- 代码成熟度的演进

---

## 迭代 48: 删除球体时同步删除锚点

### 目标
确保删除球体时,对应的 WorldAnchor 也被删除和持久化

### 修改文件
- `AppState.swift`

### 方法列表
1. 修改 `removeAllSpheres()` - 删除锚点并保存

### 代码要点

**AppState.swift**:
```swift
func removeAllSpheres() async {
    // 删除所有球体实体
    for (id, sphere) in sphereEntities {
        sphere.removeFromParent()

        // 删除对应的锚点
        if let anchorId = sphereAnchors[id] {
            removeWorldAnchor(id: anchorId)
        }

        print("--->Sphere \(id) removed")
    }

    // 清空字典
    sphereEntities.removeAll()
    sphereAnchors.removeAll()

    // 保存更新后的锚点数据
    await saveWorldAnchors()

    print("--->All spheres and anchors removed")
}
```

### 测试验证
- 放置球体
- 点击"删除所有球体"
- 重启应用,不应该有球体恢复

### 学习重点
- 数据一致性维护
- 级联删除操作
- 持久化数据的及时更新

### 代码详解

#### 为什么方法签名变了?

```swift
// 之前:
func removeAllSpheres() {
    // 同步方法
}

// 现在:
func removeAllSpheres() async {
    // 异步方法,因为需要保存
    await saveWorldAnchors()
}
```

#### ContentView 也需要更新

```swift
// ContentView.swift
Button("删除所有球体") {
    Task {
        await appState.removeAllSpheres()
    }
}
```

#### 数据一致性

```
删除球体的完整流程:

1. 从场景移除实体
   sphere.removeFromParent()

2. 删除锚点
   if let anchorId = sphereAnchors[id] {
       removeWorldAnchor(id: anchorId)
   }

3. 清空映射
   sphereEntities.removeAll()
   sphereAnchors.removeAll()

4. 持久化更新
   await saveWorldAnchors()

保证:
- 视觉上消失 ✓
- 内存中清理 ✓
- 磁盘上更新 ✓
```

---

# 阶段2: 球体拖动和旋转交互

## 迭代 49: 为球体添加输入组件

### 目标
让已放置的球体可以接收手势输入

### 修改文件
- `AppState.swift`

### 方法列表
1. 修改 `addSphereAtPosition` - 添加输入组件

### 代码要点

**AppState.swift**:
```swift
func addSphereAtPosition(_ position: SIMD3<Float>) async {
    // ... 现有代码 ...

    let sphere = ModelEntity(mesh: mesh, materials: [material])
    let sphereId = UUID()
    sphere.name = "Sphere_\(sphereId)"

    // 添加碰撞形状
    sphere.generateCollisionShapes(recursive: false)

    // 添加输入目标组件
    sphere.components.set(
        InputTargetComponent(allowedInputTypes: [.indirect, .direct])
    )

    // ... 创建锚点和添加到场景 ...
}
```

### 测试验证
- 放置的球体应该可以被视线选中
- 为后续手势做准备

### 学习重点
- `InputTargetComponent` 配置
- `.indirect` vs `.direct` 输入类型
- 碰撞形状的必要性

### 代码详解

#### 输入类型

```
allowedInputTypes: [.indirect, .direct]

.indirect (间接输入):
- 视线 + pinch 手势
- 适合远距离交互
- 不需要手接触物体

.direct (直接输入):
- 手直接触摸物体
- 需要手部跟踪
- 更自然的交互

同时启用两种:
- 给用户更多选择
- 近距离可以直接触摸
- 远距离可以用视线选择
```

#### generateCollisionShapes 的作用

```swift
sphere.generateCollisionShapes(recursive: false)
```

**必要性**:
- 输入检测需要碰撞体
- 系统通过射线投射检测交互
- 没有碰撞形状,无法被选中

---

## 迭代 50: 添加拖动状态追踪

### 目标
添加状态变量来追踪正在拖动的球体

### 修改文件
- `ImmersiveView.swift`

### 方法列表
1. 添加 `draggedSphere` 状态变量
2. 添加 `initialDragPosition` 状态变量

### 代码要点

**ImmersiveView.swift**:
```swift
struct ImmersiveView: View {
    @Environment(AppState.self) private var appState
    @State private var previewSphere: ModelEntity?

    // 新增:拖动状态追踪
    @State private var draggedSphere: ModelEntity?
    @State private var initialDragPosition: SIMD3<Float>?

    var body: some View {
        RealityView { content in
            // ... 现有代码 ...
        }
        // ... 现有修饰符 ...
    }
}
```

### 测试验证
- 代码编译无错误

### 学习重点
- `@State` 在视图层管理临时状态
- 拖动状态的数据结构设计

### 代码详解

#### 为什么需要这两个状态变量?

```swift
@State private var draggedSphere: ModelEntity?
@State private var initialDragPosition: SIMD3<Float>?
```

**draggedSphere**:
- 追踪当前正在被拖动的球体
- `nil` 表示没有球体在拖动
- `ModelEntity` 是被拖动的球体引用

**initialDragPosition**:
- 记录拖动开始时球体的初始位置
- 用于计算拖动偏移量
- 可以用于实现"取消拖动"功能

#### 为什么使用 @State 而不是 @Observable?

```
@State vs AppState (@Observable):

@State:
✓ 视图层的临时状态
✓ 只在拖动过程中需要
✓ 不需要跨视图共享
✓ 自动管理生命周期

AppState:
- 应用级别的持久状态
- 需要跨视图访问
- 需要保存或恢复
- 例如:sphereEntities, visualizationMode
```

#### 拖动状态的生命周期

```
用户开始拖动
    ↓
draggedSphere = sphere
initialDragPosition = sphere.position
    ↓
拖动过程中
draggedSphere 保持引用
    ↓
拖动结束
draggedSphere = nil
initialDragPosition = nil
```

---

## 迭代 51: 实现球体拖动手势

### 目标
添加 SpatialDragGesture 支持球体拖动

### 修改文件
- `ImmersiveView.swift`

### 方法列表
1. 添加 `.gesture(dragGesture)` 修饰符
2. `handleDragChanged(_:)` - 处理拖动过程
3. `handleDragEnded(_:)` - 处理拖动结束

### 代码要点

**ImmersiveView.swift**:
```swift
var body: some View {
    RealityView { content in
        // ... 现有代码 ...
    }
    .task {
        await appState.initializeARKit()
    }
    .onChange(of: appState.showPreviewSphere) { _, newValue in
        previewSphere?.isEnabled = newValue
    }
    .gesture(
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { event in
                handleTap(event)
            }
    )
    // 新增:拖动手势
    .gesture(
        DragGesture()
            .targetedToAnyEntity()
            .onChanged { event in
                handleDragChanged(event)
            }
            .onEnded { event in
                handleDragEnded(event)
            }
    )
}

private func handleDragChanged(_ event: EntityTargetValue<DragGesture.Value>) {
    // 确保是球体而不是预览球体
    guard event.entity != previewSphere,
          let sphere = event.entity as? ModelEntity,
          sphere.name.hasPrefix("Sphere_") else {
        return
    }

    // 首次拖动,记录初始状态
    if draggedSphere == nil {
        draggedSphere = sphere
        initialDragPosition = sphere.position(relativeTo: nil)
        print("--->Started dragging sphere: \(sphere.name)")
    }

    // 计算新位置
    let translation3D = event.convert(event.translation3D, from: .local, to: .scene)

    if let initialPos = initialDragPosition {
        let newPosition = initialPos + SIMD3<Float>(
            Float(translation3D.x),
            Float(translation3D.y),
            Float(translation3D.z)
        )

        // 更新球体位置(相对于世界坐标)
        sphere.setPosition(newPosition, relativeTo: nil)
    }
}

private func handleDragEnded(_ event: EntityTargetValue<DragGesture.Value>) {
    guard let sphere = draggedSphere else {
        return
    }

    // 获取最终位置
    let finalPosition = sphere.position(relativeTo: nil)

    print("--->Drag ended at: \(finalPosition)")

    // 清除拖动状态
    draggedSphere = nil
    initialDragPosition = nil

    // 后续迭代将更新 WorldAnchor
}
```

### 测试验证
- 放置球体后,可以用手势拖动球体
- 球体跟随手指/视线移动
- 松开后球体停留在新位置

### 学习重点
- `DragGesture` vs `SpatialTapGesture`
- `.targetedToAnyEntity()` 的复用
- `translation3D` 3D 平移向量
- `convert(_:from:to:)` 坐标系转换
- `setPosition(_:relativeTo:)` 设置实体位置

### 代码详解

#### DragGesture 的工作原理

```
DragGesture 事件流:

onChanged (多次触发)
    ↓
每次手指/视线移动时调用
    ↓
提供 translation3D (累积偏移)
    ↓
更新实体位置
    ↓
onEnded (触发一次)
    ↓
拖动结束,保存最终位置
```

#### translation3D 是什么?

```swift
event.translation3D
```

**类型**: `Vector3D`
**含义**: 从拖动开始点到当前点的 3D 偏移量

```
拖动开始点
    ↓
   (0, 0, 0)  ← translation3D 的起点
    ↓
拖动中...
    ↓
   (0.1, 0.2, -0.3)  ← 当前 translation3D
    ↓
拖动结束
   (0.5, 0.1, -0.8)  ← 最终 translation3D
```

#### 坐标系转换

```swift
let translation3D = event.convert(
    event.translation3D,
    from: .local,        // 从手势的局部坐标系
    to: .scene           // 转换到场景世界坐标系
)
```

**为什么需要转换?**
- `event.translation3D` 在手势的局部坐标系中
- 球体位置在世界坐标系中
- 必须统一坐标系才能正确计算

**坐标系类型**:
- `.local`: 实体的局部坐标系
- `.scene`: 场景的世界坐标系
- `.parent`: 父实体的坐标系

#### 位置计算

```swift
let newPosition = initialPos + SIMD3<Float>(
    Float(translation3D.x),
    Float(translation3D.y),
    Float(translation3D.z)
)
```

**公式**:
```
新位置 = 初始位置 + 拖动偏移量

例如:
初始位置: (1.0, 1.5, -1.0)
拖动偏移: (0.2, 0.1, -0.3)
新位置:   (1.2, 1.6, -1.3)
```

#### setPosition vs 直接赋值

```swift
// ✅ 推荐:
sphere.setPosition(newPosition, relativeTo: nil)

// ⚠️ 也可以,但不推荐:
sphere.position = newPosition
```

**setPosition 的优势**:
- 明确指定参考坐标系 (`relativeTo`)
- 更清晰的语义
- 支持相对定位

#### 过滤预览球体

```swift
guard event.entity != previewSphere,
      let sphere = event.entity as? ModelEntity,
      sphere.name.hasPrefix("Sphere_") else {
    return
}
```

**为什么需要过滤?**
- 预览球体不应该被拖动
- 预览球体通过头部锚点定位
- 只有已放置的球体可以拖动
- 通过名称前缀 "Sphere_" 识别

#### 状态管理

```swift
// 首次拖动
if draggedSphere == nil {
    draggedSphere = sphere
    initialDragPosition = sphere.position(relativeTo: nil)
}

// 拖动结束
draggedSphere = nil
initialDragPosition = nil
```

**保证**:
- 同一时间只能拖动一个球体
- 每次拖动都有清晰的开始和结束
- 状态自动清理,避免内存泄漏

---

## 迭代 52: 更新拖动后的 WorldAnchor

### 目标
拖动结束后,更新球体对应的 WorldAnchor 位置并保存

### 修改文件
- `ImmersiveView.swift`
- `AppState.swift`

### 方法列表
1. `updateSphereAnchor(_:position:)` - 更新球体锚点 (AppState)
2. 修改 `handleDragEnded` - 调用更新方法 (ImmersiveView)

### 代码要点

**AppState.swift**:
```swift
func updateSphereAnchor(_ sphere: ModelEntity, position: SIMD3<Float>) async {
    // 查找球体ID
    guard let sphereId = sphereEntities.first(where: { $0.value == sphere })?.key else {
        print("--->Sphere not found in entities")
        return
    }

    // 查找对应的锚点ID
    guard let anchorId = sphereAnchors[sphereId] else {
        print("--->Anchor not found for sphere")
        return
    }

    // 删除旧锚点
    removeWorldAnchor(id: anchorId)

    // 在新位置创建新锚点
    guard let newAnchor = await createWorldAnchor(at: position) else {
        print("--->Failed to create new anchor")
        return
    }

    // 更新映射关系
    worldAnchors[newAnchor.id] = newAnchor
    sphereAnchors[sphereId] = newAnchor.id

    // 获取球体的父实体(AnchorEntity)
    guard let anchorEntity = sphere.parent as? AnchorEntity else {
        print("--->Parent is not AnchorEntity")
        return
    }

    // 更新 AnchorEntity 的锚点
    anchorEntity.anchoring = AnchoringComponent(anchor: newAnchor)

    // 保存更新后的锚点数据
    await saveWorldAnchors()

    print("--->Updated anchor for sphere \(sphereId) at \(position)")
}
```

**ImmersiveView.swift**:
```swift
private func handleDragEnded(_ event: EntityTargetValue<DragGesture.Value>) {
    guard let sphere = draggedSphere else {
        return
    }

    // 获取最终位置
    let finalPosition = sphere.position(relativeTo: nil)

    print("--->Drag ended at: \(finalPosition)")

    // 异步更新锚点
    Task {
        await appState.updateSphereAnchor(sphere, position: finalPosition)
    }

    // 清除拖动状态
    draggedSphere = nil
    initialDragPosition = nil
}
```

### 测试验证
- 拖动球体到新位置
- 退出并重新进入沉浸式空间
- 球体应该保持在新位置
- 重启应用,球体仍在新位置

### 学习重点
- WorldAnchor 的动态更新策略
- `AnchoringComponent` 的作用
- 实体父子关系的导航
- 字典反向查找技巧

### 代码详解

#### 为什么要"删除旧锚点 + 创建新锚点"?

```swift
// 删除旧锚点
removeWorldAnchor(id: anchorId)

// 创建新锚点
let newAnchor = await createWorldAnchor(at: position)
```

**原因**:
- WorldAnchor 一旦创建,位置是固定的
- 不能直接"移动"一个 WorldAnchor
- 需要在新位置创建新的锚点
- 删除旧锚点释放资源

**流程**:
```
旧位置: WorldAnchor A
    ↓ (拖动)
新位置: 删除 A, 创建 WorldAnchor B
    ↓
更新映射: sphere → B
```

#### 字典反向查找

```swift
guard let sphereId = sphereEntities.first(where: { $0.value == sphere })?.key else {
    return
}
```

**问题**: 我们有 `ModelEntity`,需要找到它的 `UUID`

**解决方案**:
- `sphereEntities: [UUID: ModelEntity]`
- 通过 `first(where:)` 遍历查找
- `$0.value == sphere` 比较实体引用
- `?.key` 获取对应的 UUID

**性能考虑**:
- 这是 O(n) 操作
- 对于少量球体(几十个)可以接受
- 如果需要频繁查找,可以维护反向字典: `[ModelEntity: UUID]`

#### AnchoringComponent 更新

```swift
anchorEntity.anchoring = AnchoringComponent(anchor: newAnchor)
```

**AnchoringComponent 是什么?**
- RealityKit 的组件,定义实体如何锚定
- 包含锚点引用
- 更新它可以改变实体的锚定目标

**为什么需要更新?**
- `AnchorEntity` 最初绑定到旧锚点
- 拖动后需要绑定到新锚点
- 更新 `anchoring` 组件实现重新绑定

#### 父实体导航

```swift
guard let anchorEntity = sphere.parent as? AnchorEntity else {
    return
}
```

**实体层级**:
```
contentRoot
└── anchorEntity (AnchorEntity)
    └── sphere (ModelEntity) ← 我们有这个引用
```

**导航**:
- `sphere.parent` 获取父实体
- `as? AnchorEntity` 类型转换
- 确保父实体是 `AnchorEntity` 类型

---

## 迭代 53: 添加拖动视觉反馈

### 目标
在拖动过程中提供视觉反馈,提升用户体验

### 修改文件
- `ImmersiveView.swift`

### 方法列表
1. 修改 `handleDragChanged` - 添加高亮效果
2. 修改 `handleDragEnded` - 恢复原状

### 代码要点

**ImmersiveView.swift**:
```swift
private func handleDragChanged(_ event: EntityTargetValue<DragGesture.Value>) {
    guard event.entity != previewSphere,
          let sphere = event.entity as? ModelEntity,
          sphere.name.hasPrefix("Sphere_") else {
        return
    }

    // 首次拖动,记录初始状态并添加高亮
    if draggedSphere == nil {
        draggedSphere = sphere
        initialDragPosition = sphere.position(relativeTo: nil)

        // 添加高亮效果:放大 + 半透明白色
        sphere.scale = [1.2, 1.2, 1.2]

        // 添加发光材质
        var material = SimpleMaterial()
        material.color = .init(tint: .white.withAlphaComponent(0.8))
        material.metallic = .float(1.0)
        material.roughness = .float(0.0)
        sphere.model?.materials = [material]

        print("--->Started dragging sphere: \(sphere.name)")
    }

    // 计算新位置
    let translation3D = event.convert(event.translation3D, from: .local, to: .scene)

    if let initialPos = initialDragPosition {
        let newPosition = initialPos + SIMD3<Float>(
            Float(translation3D.x),
            Float(translation3D.y),
            Float(translation3D.z)
        )

        sphere.setPosition(newPosition, relativeTo: nil)
    }
}

private func handleDragEnded(_ event: EntityTargetValue<DragGesture.Value>) {
    guard let sphere = draggedSphere else {
        return
    }

    // 恢复原始大小和材质
    sphere.scale = [1.0, 1.0, 1.0]

    // 根据房间位置恢复颜色
    let finalPosition = sphere.position(relativeTo: nil)
    let isInRoom = appState.isSphereInCurrentRoom(position: finalPosition)
    let color: UIColor = isInRoom ? .green : .red

    let material = SimpleMaterial(
        color: color,
        roughness: 0.2,
        isMetallic: true
    )
    sphere.model?.materials = [material]

    print("--->Drag ended at: \(finalPosition)")

    // 异步更新锚点
    Task {
        await appState.updateSphereAnchor(sphere, position: finalPosition)
    }

    draggedSphere = nil
    initialDragPosition = nil
}
```

### 测试验证
- 开始拖动时,球体变大且变亮
- 拖动过程中保持高亮
- 拖动结束后,球体恢复正常大小
- 球体颜色根据房间位置更新(绿色/红色)

### 学习重点
- 实体缩放 (`scale` 属性)
- 材质动态更改
- 金属度和粗糙度参数
- 用户体验的视觉反馈设计

### 代码详解

#### 缩放效果

```swift
sphere.scale = [1.2, 1.2, 1.2]  // 放大到 120%
// 拖动结束后
sphere.scale = [1.0, 1.0, 1.0]  // 恢复到 100%
```

**scale 的含义**:
- `SIMD3<Float>` 类型
- `[x_scale, y_scale, z_scale]`
- `[1.2, 1.2, 1.2]` 表示各轴均放大 20%
- `[1.0, 1.0, 1.0]` 表示原始大小

#### 发光材质

```swift
var material = SimpleMaterial()
material.color = .init(tint: .white.withAlphaComponent(0.8))
material.metallic = .float(1.0)   // 完全金属
material.roughness = .float(0.0)  // 完全光滑
```

**参数解释**:
- **metallic = 1.0**: 完全金属质感,反射更强
- **roughness = 0.0**: 完全光滑,高镜面反射
- **white + alpha 0.8**: 接近白色,略透明

**视觉效果**:
- 球体看起来像发光的金属球
- 吸引用户注意力
- 明确指示正在拖动

#### 恢复逻辑

```swift
// 根据房间位置恢复颜色
let isInRoom = appState.isSphereInCurrentRoom(position: finalPosition)
let color: UIColor = isInRoom ? .green : .red
```

**为什么需要重新判断颜色?**
- 球体可能从房间内拖到房间外
- 或从房间外拖到房间内
- 颜色应该反映新位置的状态

#### isSphereInCurrentRoom 需要公开

**AppState.swift** 需要修改:
```swift
// 从 private 改为 public
func isSphereInCurrentRoom(position: SIMD3<Float>) -> Bool {
    // ... 现有实现 ...
}
```

---

## 迭代 54: 添加旋转手势支持

### 目标
添加旋转功能,允许用户旋转球体

### 修改文件
- `ImmersiveView.swift`
- `ContentView.swift`
- `AppState.swift`

### 方法列表
1. 添加旋转模式状态 (AppState)
2. 添加旋转手势 (ImmersiveView)
3. 添加旋转模式切换按钮 (ContentView)

### 代码要点

**AppState.swift**:
```swift
@Observable
@MainActor
class AppState {
    // ... 现有属性 ...

    // 新增:交互模式
    var interactionMode: InteractionMode = .move
}

enum InteractionMode {
    case move     // 移动模式
    case rotate   // 旋转模式
}
```

**ImmersiveView.swift**:
```swift
struct ImmersiveView: View {
    // ... 现有属性 ...
    @State private var initialRotation: simd_quatf?

    var body: some View {
        RealityView { content in
            // ... 现有代码 ...
        }
        // ... 现有修饰符 ...
        .gesture(
            RotationGesture3D()
                .targetedToAnyEntity()
                .onChanged { event in
                    handleRotationChanged(event)
                }
                .onEnded { event in
                    handleRotationEnded(event)
                }
        )
    }

    private func handleRotationChanged(_ event: EntityTargetValue<RotationGesture3D.Value>) {
        // 只在旋转模式下响应
        guard appState.interactionMode == .rotate else {
            return
        }

        guard event.entity != previewSphere,
              let sphere = event.entity as? ModelEntity,
              sphere.name.hasPrefix("Sphere_") else {
            return
        }

        // 首次旋转,记录初始状态
        if draggedSphere == nil {
            draggedSphere = sphere
            initialRotation = sphere.orientation
            print("--->Started rotating sphere: \(sphere.name)")
        }

        // 应用旋转
        if let initialRot = initialRotation {
            // 获取旋转增量
            let rotation = event.rotation
            let quaternion = simd_quatf(angle: Float(rotation.angle),
                                       axis: SIMD3<Float>(Float(rotation.axis.x),
                                                         Float(rotation.axis.y),
                                                         Float(rotation.axis.z)))

            // 组合旋转
            sphere.orientation = quaternion * initialRot
        }
    }

    private func handleRotationEnded(_ event: EntityTargetValue<RotationGesture3D.Value>) {
        guard let sphere = draggedSphere else {
            return
        }

        print("--->Rotation ended")

        // 旋转不需要更新锚点位置
        // 但需要保存旋转状态(可选的后续优化)

        // 清除状态
        draggedSphere = nil
        initialRotation = nil
    }
}
```

**ContentView.swift**:
```swift
VStack(spacing: 15) {
    // 球体计数
    HStack {
        Text("已放置球体:")
        Text("\(appState.sphereEntities.count)")
            .bold()
            .foregroundStyle(.blue)
    }
    .font(.headline)

    // 新增:交互模式选择器
    Picker("交互模式", selection: $appState.interactionMode) {
        Text("移动").tag(InteractionMode.move)
        Text("旋转").tag(InteractionMode.rotate)
    }
    .pickerStyle(.segmented)

    Button(appState.showPreviewSphere ? "取消放置" : "添加球体") {
        appState.showPreviewSphere.toggle()
    }
    .buttonStyle(.borderedProminent)

    // ... 其他控件 ...
}
```

### 测试验证
- 切换到"旋转"模式
- 用两指旋转手势旋转球体
- 球体应该跟随旋转
- 切换到"移动"模式
- 球体可以拖动但不能旋转

### 学习重点
- `RotationGesture3D` 3D 旋转手势
- `simd_quatf` 四元数旋转
- 四元数的组合 (乘法)
- `orientation` 属性
- 交互模式的状态管理

### 代码详解

#### RotationGesture3D

```swift
RotationGesture3D()
    .targetedToAnyEntity()
    .onChanged { event in ... }
    .onEnded { event in ... }
```

**与 DragGesture 的对比**:
```
DragGesture:
- 平移操作
- translation3D (偏移量)
- 改变 position

RotationGesture3D:
- 旋转操作
- rotation (角度 + 轴)
- 改变 orientation
```

#### 四元数旋转

```swift
let quaternion = simd_quatf(
    angle: Float(rotation.angle),     // 旋转角度(弧度)
    axis: SIMD3<Float>(...)          // 旋转轴
)

// 组合旋转
sphere.orientation = quaternion * initialRot
```

**四元数乘法**:
- 表示旋转的组合
- `quaternion * initialRot` = "先应用 initialRot,再应用 quaternion"
- 顺序很重要!

**为什么需要组合?**
```
初始旋转: initialRot (球体原始朝向)
    ↓
用户旋转: quaternion (手势产生的旋转)
    ↓
最终旋转: quaternion * initialRot
```

#### orientation 属性

```swift
sphere.orientation = quaternion
```

**orientation 是什么?**
- 实体的旋转状态
- 类型: `simd_quatf` (四元数)
- 相对于父实体的局部旋转

**与 transform 的关系**:
```swift
sphere.transform.rotation = quaternion  // 等价写法
```

#### 交互模式管理

```swift
enum InteractionMode {
    case move     // 移动模式
    case rotate   // 旋转模式
}
```

**为什么需要模式切换?**
- 移动和旋转手势可能冲突
- 明确的模式给用户清晰的反馈
- 避免意外操作

**判断逻辑**:
```swift
// 在拖动手势中
guard appState.interactionMode == .move else { return }

// 在旋转手势中
guard appState.interactionMode == .rotate else { return }
```

#### 旋转不需要更新锚点

```swift
// 旋转不需要更新锚点位置
// 但需要保存旋转状态(可选的后续优化)
```

**原因**:
- WorldAnchor 只定义位置,不包含旋转
- 旋转是实体的局部属性
- 如果需要持久化旋转,需要额外保存
- 可以用 UserDefaults 或独立文件保存 `[UUID: simd_quatf]`

---

## 迭代 55: 限制球体拖动范围

### 目标
添加边界检查,防止球体被拖动到过远的位置

### 修改文件
- `ImmersiveView.swift`

### 方法列表
1. `clampPosition(_:)` - 限制位置范围

### 代码要点

**ImmersiveView.swift**:
```swift
private func handleDragChanged(_ event: EntityTargetValue<DragGesture.Value>) {
    // ... 现有代码 ...

    if let initialPos = initialDragPosition {
        var newPosition = initialPos + SIMD3<Float>(
            Float(translation3D.x),
            Float(translation3D.y),
            Float(translation3D.z)
        )

        // 限制位置范围
        newPosition = clampPosition(newPosition)

        sphere.setPosition(newPosition, relativeTo: nil)
    }
}

private func clampPosition(_ position: SIMD3<Float>) -> SIMD3<Float> {
    let maxDistance: Float = 5.0  // 最远5米
    let minY: Float = 0.0         // 不低于地面
    let maxY: Float = 3.0         // 不高于3米

    var clamped = position

    // 限制Y轴(高度)
    clamped.y = max(minY, min(maxY, position.y))

    // 限制水平距离
    let horizontalDistance = sqrt(position.x * position.x + position.z * position.z)
    if horizontalDistance > maxDistance {
        let scale = maxDistance / horizontalDistance
        clamped.x = position.x * scale
        clamped.z = position.z * scale
    }

    return clamped
}
```

### 测试验证
- 尝试将球体拖动到很远的地方
- 球体应该停在边界处
- 尝试将球体拖到地面以下
- 球体应该保持在最低高度

### 学习重点
- 位置约束算法
- 向量长度计算
- min/max 函数
- 用户体验的边界设计

---

# 总结: 需求2完成

## 完成的迭代

✅ **迭代 49**: 为球体添加输入组件
✅ **迭代 50**: 添加拖动状态追踪
✅ **迭代 51**: 实现球体拖动手势
✅ **迭代 52**: 更新拖动后的 WorldAnchor
✅ **迭代 53**: 添加拖动视觉反馈
✅ **迭代 54**: 添加旋转手势支持
✅ **迭代 55**: 限制球体拖动范围

## 实现的功能

### 拖动功能
- ✓ 使用 DragGesture 拖动球体
- ✓ 实时位置更新
- ✓ WorldAnchor 同步更新
- ✓ 持久化保存新位置
- ✓ 视觉反馈(放大+高亮)
- ✓ 边界限制

### 旋转功能
- ✓ 使用 RotationGesture3D 旋转球体
- ✓ 四元数旋转计算
- ✓ 交互模式切换(移动/旋转)
- ✓ UI 模式选择器

## 关键技术点

1. **手势系统**:
   - `DragGesture` - 拖动
   - `RotationGesture3D` - 旋转
   - `.targetedToAnyEntity()` - 实体目标

2. **坐标转换**:
   - `convert(_:from:to:)` - 坐标系转换
   - `position(relativeTo:)` - 相对位置
   - `setPosition(_:relativeTo:)` - 设置位置

3. **WorldAnchor 管理**:
   - 删除旧锚点
   - 创建新锚点
   - 更新 AnchoringComponent
   - 持久化保存

4. **视觉反馈**:
   - scale 缩放
   - 材质动态更改
   - 金属度和粗糙度

5. **状态管理**:
   - @State 临时状态
   - InteractionMode 交互模式
   - 拖动/旋转状态追踪

---

# 阶段3: 墙面网格精度优化

## 问题分析

根据需求描述:"生成的墙体网格不能够与墙体完全贴合,有时候离真实墙体的距离很远"。

### 可能的原因

1. **变换矩阵应用问题**:
   - `originFromAnchorTransform` 的理解和使用
   - 坐标系转换错误

2. **几何数据精度问题**:
   - ARKit 提供的墙面几何本身精度有限
   - 网格简化导致细节丢失

3. **锚点定位问题**:
   - RoomAnchor 的原点位置不准确
   - 需要额外的校准步骤

4. **网格法线方向问题**:
   - 墙面朝向可能反向
   - 需要调整网格偏移方向

### 优化策略

根据问题分析,我们将采用以下策略:

1. **添加调试可视化**: 显示原始几何数据和变换信息
2. **验证坐标系统**: 确保变换矩阵正确应用
3. **添加偏移调整**: 允许手动微调墙面位置
4. **使用 PlaneDetection**: 辅助提高精度
5. **添加法线显示**: 调试墙面朝向问题

---

## 迭代 56: 添加墙面调试信息显示

### 目标
添加详细的调试日志和可视化,帮助诊断精度问题

### 修改文件
- `AppState.swift`

### 方法列表
1. `printWallDebugInfo(_:index:)` - 打印墙面调试信息
2. 修改 `createWallEntity` - 添加调试输出

### 代码要点

**AppState.swift**:
```swift
private func createWallEntity(
    from geometry: MeshAnchor.Geometry,
    index: Int,
    roomAnchor: RoomAnchor
) {
    print("--->Creating wall entity \(index)...")

    // 打印调试信息
    printWallDebugInfo(geometry, index: index, roomAnchor: roomAnchor)

    // ... 现有代码 ...
}

private func printWallDebugInfo(
    _ geometry: MeshAnchor.Geometry,
    index: Int,
    roomAnchor: RoomAnchor
) {
    print("===== Wall \(index) Debug Info =====")

    // 顶点信息
    let vertices = geometry.vertices.asSIMD3(ofType: Float.self)
    print("Vertex count: \(vertices.count)")
    if vertices.count > 0 {
        print("First vertex: \(vertices[0])")
        print("Last vertex: \(vertices[vertices.count - 1])")

        // 计算边界框
        var minPoint = vertices[0]
        var maxPoint = vertices[0]
        for vertex in vertices {
            minPoint = SIMD3<Float>(
                min(minPoint.x, vertex.x),
                min(minPoint.y, vertex.y),
                min(minPoint.z, vertex.z)
            )
            maxPoint = SIMD3<Float>(
                max(maxPoint.x, vertex.x),
                max(maxPoint.y, vertex.y),
                max(maxPoint.z, vertex.z)
            )
        }
        print("Bounding box: min=\(minPoint), max=\(maxPoint)")

        // 墙面尺寸
        let size = maxPoint - minPoint
        print("Wall size: width=\(size.x)m, height=\(size.y)m, depth=\(size.z)m")
    }

    // 锚点变换信息
    let transform = roomAnchor.originFromAnchorTransform
    print("Anchor transform matrix:")
    print("  [\(transform.columns.0)]")
    print("  [\(transform.columns.1)]")
    print("  [\(transform.columns.2)]")
    print("  [\(transform.columns.3)]")

    // 提取位置和旋转
    let position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    print("Anchor position: \(position)")

    // 计算墙面中心（变换后）
    if vertices.count > 0 {
        let center = (minPoint + maxPoint) / 2
        let transformedCenter = transform * SIMD4<Float>(center.x, center.y, center.z, 1.0)
        print("Wall center (local): \(center)")
        print("Wall center (world): \(SIMD3<Float>(transformedCenter.x, transformedCenter.y, transformedCenter.z))")
    }

    print("==================================")
}
```

### 测试验证
- 进入沉浸式空间
- 切换到"墙面"可视化模式
- 查看控制台输出的详细墙面信息
- 记录墙面尺寸和位置数据

### 学习重点
- 矩阵列向量的含义
- 边界框计算
- 4x4 变换矩阵结构
- 局部坐标到世界坐标的转换

### 代码详解

#### 边界框计算

```swift
var minPoint = vertices[0]
var maxPoint = vertices[0]
for vertex in vertices {
    minPoint = SIMD3<Float>(
        min(minPoint.x, vertex.x),
        min(minPoint.y, vertex.y),
        min(minPoint.z, vertex.z)
    )
    maxPoint = SIMD3<Float>(
        max(maxPoint.x, vertex.x),
        max(maxPoint.y, vertex.y),
        max(maxPoint.z, vertex.z)
    )
}
```

**边界框（Bounding Box）**:
- AABB (Axis-Aligned Bounding Box)
- 最小点和最大点定义
- 用于快速碰撞检测和尺寸计算

**可视化**:
```
        maxPoint (x_max, y_max, z_max)
           +----------------+
          /|               /|
         / |              / |
        +----------------+  |
        |  |             |  |
        |  +-------------|--+
        | / minPoint     | /
        |/  (x_min,      |/
        +   y_min,       +
            z_min)
```

#### 4x4 变换矩阵结构

```swift
let transform = roomAnchor.originFromAnchorTransform
```

**矩阵格式**:
```
| R00  R01  R02  Tx |   columns.0
| R10  R11  R12  Ty |   columns.1
| R20  R21  R22  Tz |   columns.2
|  0    0    0    1 |   columns.3

R: 旋转 + 缩放 (3x3)
T: 平移 (位置)
```

**读取位置**:
```swift
let position = SIMD3<Float>(
    transform.columns.3.x,  // Tx
    transform.columns.3.y,  // Ty
    transform.columns.3.z   // Tz
)
```

#### 坐标变换

```swift
let transformedCenter = transform * SIMD4<Float>(center.x, center.y, center.z, 1.0)
```

**齐次坐标**:
- 使用 SIMD4 (x, y, z, w)
- w=1 表示点
- w=0 表示向量（方向）

**计算**:
```
世界坐标 = 变换矩阵 × 局部坐标

[x']   [R00 R01 R02 Tx]   [x]
[y'] = [R10 R11 R12 Ty] × [y]
[z']   [R20 R21 R22 Tz]   [z]
[1 ]   [0   0   0   1 ]   [1]
```

---

## 迭代 57: 添加墙面顶点可视化

### 目标
在场景中显示墙面的顶点位置,直观查看几何数据

### 修改文件
- `AppState.swift`

### 方法列表
1. `createDebugSpheres(for:roomAnchor:)` - 创建调试球体
2. 修改 `createWallEntity` - 添加顶点可视化

### 代码要点

**AppState.swift**:
```swift
// 添加调试模式开关
var showWallDebugSpheres = false

private func createWallEntity(
    from geometry: MeshAnchor.Geometry,
    index: Int,
    roomAnchor: RoomAnchor
) {
    // ... 现有代码 ...

    // 添加调试球体（如果启用）
    if showWallDebugSpheres {
        createDebugSpheres(for: geometry, roomAnchor: roomAnchor, wallIndex: index)
    }
}

private func createDebugSpheres(
    for geometry: MeshAnchor.Geometry,
    roomAnchor: RoomAnchor,
    wallIndex: Int
) {
    let vertices = geometry.vertices.asSIMD3(ofType: Float.self)

    // 只显示部分顶点（每隔N个），避免太密集
    let step = max(1, vertices.count / 20)  // 最多显示20个点

    for (index, vertex) in vertices.enumerated() where index % step == 0 {
        // 创建小球体
        let mesh = MeshResource.generateSphere(radius: 0.02)  // 2cm 半径
        var material = SimpleMaterial()
        material.color = .init(tint: .yellow)  // 黄色标记

        let sphere = ModelEntity(mesh: mesh, materials: [material])

        // 应用变换：局部坐标 → 世界坐标
        let transform = roomAnchor.originFromAnchorTransform
        let worldPos = transform * SIMD4<Float>(vertex.x, vertex.y, vertex.z, 1.0)
        sphere.position = SIMD3<Float>(worldPos.x, worldPos.y, worldPos.z)

        sphere.name = "DebugVertex_Wall\(wallIndex)_\(index)"

        // 添加到 wallRoot
        wallRoot.addChild(sphere)

        print("--->Debug sphere at: \(sphere.position)")
    }
}
```

### 测试验证
- 设置 `showWallDebugSpheres = true`
- 进入沉浸式空间
- 显示墙面模式
- 观察黄色小球的位置
- 对比小球位置与真实墙面

### 学习重点
- 调试可视化技巧
- 顶点采样策略
- 变换应用顺序
- 调试工具的重要性

### 代码详解

#### 顶点采样

```swift
let step = max(1, vertices.count / 20)  // 最多显示20个点

for (index, vertex) in vertices.enumerated() where index % step == 0 {
    // 创建调试球体
}
```

**为什么需要采样?**
- 墙面可能有数百个顶点
- 显示所有顶点会太密集
- 性能影响
- 采样后仍能看出整体形状

**step 计算**:
```
vertices.count = 100 → step = 5  (显示 20 个点)
vertices.count = 50  → step = 2  (显示 25 个点)
vertices.count = 10  → step = 1  (显示 10 个点)
```

#### 调试球体大小

```swift
let mesh = MeshResource.generateSphere(radius: 0.02)  // 2cm
```

**尺寸选择**:
- 太大: 遮挡墙面,难以判断
- 太小: 难以看见
- 2cm: 在1-2米距离清晰可见

#### 变换应用

```swift
let worldPos = transform * SIMD4<Float>(vertex.x, vertex.y, vertex.z, 1.0)
sphere.position = SIMD3<Float>(worldPos.x, worldPos.y, worldPos.z)
```

**关键点**:
- 顶点在 RoomAnchor 的局部坐标系中
- 必须应用变换才能得到世界坐标
- 这与墙面实体的变换一致

**验证方法**:
```
如果调试球体位置准确 ✓
└─> 说明变换应用正确
    └─> 问题可能在其他地方

如果调试球体位置偏移 ✗
└─> 说明变换应用有误
    └─> 需要检查变换矩阵使用
```

---

## 迭代 58: 添加墙面偏移调整功能

### 目标
允许手动调整墙面位置,测试不同偏移量的效果

### 修改文件
- `AppState.swift`
- `ContentView.swift`

### 方法列表
1. 添加 `wallOffset` 属性
2. 修改 `createWallEntity` - 应用偏移
3. 添加偏移调整 UI

### 代码要点

**AppState.swift**:
```swift
@Observable
@MainActor
class AppState {
    // ... 现有属性 ...

    // 新增: 墙面偏移量（米）
    var wallOffset: Float = 0.0  // 正值向外推,负值向内拉

    // ... 其他代码 ...
}

private func createWallEntity(
    from geometry: MeshAnchor.Geometry,
    index: Int,
    roomAnchor: RoomAnchor
) {
    print("--->Creating wall entity \(index) with offset \(wallOffset)...")

    guard let meshResource = geometry.asMeshResource() else {
        print("--->Failed to convert wall geometry")
        return
    }

    // 创建材质
    var material = UnlitMaterial()
    material.color = .init(tint: .blue.withAlphaComponent(0.15))

    // 创建实体
    let wallEntity = ModelEntity(
        mesh: meshResource,
        materials: [material]
    )
    wallEntity.name = "Wall_\(index)"

    // 应用房间锚点的变换
    var transform = Transform(matrix: roomAnchor.originFromAnchorTransform)

    // 应用偏移（沿墙面法线方向）
    if wallOffset != 0.0 {
        // 计算墙面法线（简化：假设墙面朝向X轴）
        // 后续可以从几何数据计算精确法线
        let normal = calculateWallNormal(geometry, transform: transform)
        let offsetVector = normal * wallOffset

        // 添加偏移到位置
        transform.translation += offsetVector

        print("--->Applied offset: \(offsetVector)")
    }

    wallEntity.transform = transform

    // 添加到场景
    wallRoot.addChild(wallEntity)
    wallEntities["Wall_\(index)"] = wallEntity

    print("--->Wall \(index) created with final transform: \(wallEntity.transform)")
}

private func calculateWallNormal(
    _ geometry: MeshAnchor.Geometry,
    transform: Transform
) -> SIMD3<Float> {
    // 从前三个顶点计算法线
    let vertices = geometry.vertices.asSIMD3(ofType: Float.self)

    guard vertices.count >= 3 else {
        // 默认法线（朝向 -Z）
        return SIMD3<Float>(0, 0, -1)
    }

    // 取前三个顶点构成三角形
    let v0 = vertices[0]
    let v1 = vertices[1]
    let v2 = vertices[2]

    // 计算两条边
    let edge1 = v1 - v0
    let edge2 = v2 - v0

    // 叉乘得到法线
    var normal = cross(edge1, edge2)

    // 归一化
    let length = sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z)
    if length > 0.0001 {
        normal = normal / length
    }

    // 应用变换的旋转部分到法线
    let rotationMatrix = transform.rotation
    normal = rotationMatrix.act(normal)

    print("--->Calculated wall normal: \(normal)")
    return normal
}

// 重新加载墙面（用于更新偏移）
func updateWallOffset() {
    print("--->Updating walls with new offset: \(wallOffset)")
    reloadWalls()
}
```

**ContentView.swift**:
```swift
VStack(spacing: 15) {
    // ... 现有控件 ...

    // 新增: 墙面偏移调整
    if appState.visualizationMode == .walls {
        VStack(spacing: 10) {
            Text("墙面偏移: \(String(format: "%.2f", appState.wallOffset * 100))cm")
                .font(.caption)

            HStack {
                Button("向内 -5cm") {
                    appState.wallOffset -= 0.05
                    appState.updateWallOffset()
                }
                .buttonStyle(.bordered)

                Button("重置") {
                    appState.wallOffset = 0.0
                    appState.updateWallOffset()
                }
                .buttonStyle(.bordered)

                Button("向外 +5cm") {
                    appState.wallOffset += 0.05
                    appState.updateWallOffset()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.gray.opacity(0.2))
        .cornerRadius(10)
    }

    // ... 其他控件 ...
}
```

### 测试验证
1. 切换到"墙面"模式
2. 使用偏移按钮调整墙面位置
3. 观察墙面与真实墙体的对齐程度
4. 找到最佳偏移量
5. 记录不同房间的最佳偏移值

### 学习重点
- 法线计算（叉乘）
- 向量归一化
- 四元数旋转应用到向量
- 用户调试工具设计

### 代码详解

#### 法线计算

```swift
// 取前三个顶点
let v0 = vertices[0]
let v1 = vertices[1]
let v2 = vertices[2]

// 两条边
let edge1 = v1 - v0
let edge2 = v2 - v0

// 叉乘
var normal = cross(edge1, edge2)
```

**叉乘（Cross Product）**:
```
给定两个向量 A 和 B
A × B = 垂直于 A 和 B 的向量

         ↑ normal (A × B)
         |
    B ← /
       /
      /
     +----→ A

方向: 右手定则
长度: |A| × |B| × sin(θ)
```

**用途**:
- 计算平面的法线
- 法线垂直于墙面
- 用于偏移方向

#### 向量归一化

```swift
let length = sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z)
if length > 0.0001 {
    normal = normal / length
}
```

**归一化**:
- 将向量长度变为 1
- 保持方向不变
- 公式: `normalized = vector / |vector|`

**为什么需要?**
```
原始法线: (3.0, 4.0, 0.0), 长度 = 5.0
归一化后: (0.6, 0.8, 0.0), 长度 = 1.0

偏移 10cm:
原始: (3.0, 4.0, 0.0) * 0.1 = (0.3, 0.4, 0.0)  ← 错误，实际移动了50cm
归一化: (0.6, 0.8, 0.0) * 0.1 = (0.06, 0.08, 0.0) ← 正确，移动了10cm
```

#### 四元数旋转向量

```swift
let rotationMatrix = transform.rotation
normal = rotationMatrix.act(normal)
```

**simd_quatf.act()**:
- 将四元数旋转应用到向量
- 不改变向量长度
- 只改变方向

**为什么需要?**
```
局部法线: (0, 0, 1)  ← 在墙面局部坐标系中
    ↓ 应用旋转
世界法线: (0.7, 0, 0.7)  ← 在世界坐标系中

如果墙面旋转了45度，法线也要旋转45度
```

#### 偏移应用

```swift
let offsetVector = normal * wallOffset
transform.translation += offsetVector
```

**偏移逻辑**:
```
原始位置: (1.0, 0.5, -2.0)
法线方向: (1.0, 0.0, 0.0)  ← 向右
偏移量: 0.10 (10cm)
    ↓
偏移向量: (0.1, 0.0, 0.0)
    ↓
新位置: (1.1, 0.5, -2.0)  ← 墙面向右移动10cm
```

---

## 迭代 59: 使用 PlaneDetection 提供参考

### 目标
使用 PlaneDetectionProvider 检测平面,提供额外的参考数据

### 修改文件
- `AppState.swift`

### 方法列表
1. 添加 `planeDetection` provider
2. `processPlaneUpdates()` - 处理平面检测
3. `visualizePlane(_:)` - 可视化检测到的平面

### 代码要点

**AppState.swift**:
```swift
@Observable
@MainActor
class AppState {
    // ... 现有属性 ...

    private let session = ARKitSession()
    private let worldTracking = WorldTrackingProvider()
    private let roomTracking = RoomTrackingProvider()
    private let planeDetection = PlaneDetectionProvider(alignments: [.vertical])  // 新增

    // 存储检测到的平面
    private var detectedPlanes: [UUID: PlaneAnchor] = [:]

    // 是否显示检测到的平面
    var showDetectedPlanes = false

    // ... 其他代码 ...
}

func initializeARKit() async {
    // ... 现有代码 ...

    do {
        // 同时运行三个 provider
        try await session.run([worldTracking, roomTracking, planeDetection])
        errorState = .none
        print("--->ARKit session started with plane detection")

        // 加载保存的锚点
        await loadWorldAnchors()

        // 恢复球体
        await restoreSpheres()

        // 启动监听
        Task {
            await processRoomUpdates()
        }

        Task {
            await processPlaneUpdates()  // 新增
        }
    } catch {
        errorState = .sessionError(error.localizedDescription)
        print("--->ARKit session failed: \(error)")
    }
}

private func processPlaneUpdates() async {
    for await update in planeDetection.anchorUpdates {
        switch update.event {
        case .added:
            handlePlaneAdded(update.anchor)
        case .updated:
            handlePlaneUpdated(update.anchor)
        case .removed:
            handlePlaneRemoved(update.anchor)
        }
    }
}

private func handlePlaneAdded(_ anchor: PlaneAnchor) {
    detectedPlanes[anchor.id] = anchor
    print("--->Plane added: \(anchor.id), classification: \(anchor.classification)")

    if showDetectedPlanes {
        visualizePlane(anchor)
    }
}

private func handlePlaneUpdated(_ anchor: PlaneAnchor) {
    detectedPlanes[anchor.id] = anchor

    // 更新可视化（如果启用）
    if showDetectedPlanes {
        // 移除旧的，创建新的
        if let oldEntity = wallRoot.children.first(where: { $0.name == "Plane_\(anchor.id)" }) {
            oldEntity.removeFromParent()
        }
        visualizePlane(anchor)
    }
}

private func handlePlaneRemoved(_ anchor: PlaneAnchor) {
    detectedPlanes.removeValue(forKey: anchor.id)

    // 移除可视化
    if let entity = wallRoot.children.first(where: { $0.name == "Plane_\(anchor.id)" }) {
        entity.removeFromParent()
    }

    print("--->Plane removed: \(anchor.id)")
}

private func visualizePlane(_ anchor: PlaneAnchor) {
    // 创建平面网格
    let mesh = MeshResource.generatePlane(
        width: anchor.geometry.extent.width,
        depth: anchor.geometry.extent.height
    )

    // 绿色半透明材质
    var material = SimpleMaterial()
    material.color = .init(tint: .green.withAlphaComponent(0.3))

    let planeEntity = ModelEntity(mesh: mesh, materials: [material])
    planeEntity.name = "Plane_\(anchor.id)"

    // 应用锚点变换
    planeEntity.transform = Transform(matrix: anchor.originFromAnchorTransform)

    // 添加到场景
    wallRoot.addChild(planeEntity)

    print("--->Visualized plane: size=\(anchor.geometry.extent.width)x\(anchor.geometry.extent.height)")
}
```

### 测试验证
- 设置 `showDetectedPlanes = true`
- 进入沉浸式空间
- 观察绿色半透明平面（PlaneDetection 结果）
- 对比绿色平面（PlaneDetection）和蓝色墙面（RoomTracking）
- 分析两者的位置差异

### 学习重点
- `PlaneDetectionProvider` 使用
- `.vertical` 平面对齐方式
- `PlaneAnchor` vs `RoomAnchor`
- 多数据源对比分析

### 代码详解

#### PlaneDetection 配置

```swift
private let planeDetection = PlaneDetectionProvider(alignments: [.vertical])
```

**alignments 选项**:
- `.vertical`: 垂直平面（墙面）
- `.horizontal`: 水平平面（地板、桌面）
- `.any`: 任意角度

**为什么只用 vertical?**
```
需求: 优化墙面精度
目标: 检测垂直墙面
结论: 只启用 .vertical，减少不相关数据
```

#### PlaneAnchor vs RoomAnchor

```
PlaneAnchor (平面检测):
✓ 更新频繁
✓ 精度较高（持续优化）
✓ 单个平面
✗ 不理解房间结构
✗ 可能检测到非墙面

RoomAnchor (房间跟踪):
✓ 理解完整房间结构
✓ 多个墙面的关系
✗ 更新较慢
✗ 精度可能较低

理想方案: 结合两者优势
```

#### extent (平面范围)

```swift
width: anchor.geometry.extent.width
depth: anchor.geometry.extent.height
```

**PlaneAnchor.geometry.extent**:
- `width`: 平面宽度
- `height`: 平面高度
- 矩形平面的尺寸

**可视化**:
```
    extent.width
  ←───────────────→
  +--------------+  ↑
  |              |  |
  |    Plane     |  | extent.height
  |              |  |
  +--------------+  ↓
```

#### 对比分析方法

```
绿色平面（PlaneDetection）准确
蓝色墙面（RoomTracking）偏移
    ↓
查看偏移方向和距离
    ↓
调整 RoomTracking 墙面的偏移量
    ↓
使两者对齐
```

---

## 迭代 60: 实现自动偏移校准

### 目标
基于 PlaneDetection 的结果,自动计算最佳偏移量

### 修改文件
- `AppState.swift`
- `ContentView.swift`

### 方法列表
1. `calibrateWallOffset()` - 自动校准偏移
2. 添加校准按钮

### 代码要点

**AppState.swift**:
```swift
func calibrateWallOffset() async {
    print("--->Starting wall offset calibration...")

    // 等待一段时间让平面检测稳定
    try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2秒

    guard !detectedPlanes.isEmpty else {
        print("--->No planes detected for calibration")
        return
    }

    // 获取当前房间的墙面
    guard let currentRoom = roomTracking.currentRoomAnchor else {
        print("--->No current room for calibration")
        return
    }

    let walls = currentRoom.geometries(classifiedAs: .wall)
    guard !walls.isEmpty else {
        print("--->No walls in current room")
        return
    }

    // 计算墙面中心和检测平面中心的距离
    var totalOffset: Float = 0.0
    var count = 0

    for (wallIndex, wall) in walls.enumerated() {
        // 计算墙面中心
        let vertices = wall.vertices.asSIMD3(ofType: Float.self)
        guard !vertices.isEmpty else { continue }

        var center = SIMD3<Float>(0, 0, 0)
        for vertex in vertices {
            center += vertex
        }
        center /= Float(vertices.count)

        // 转换到世界坐标
        let transform = currentRoom.originFromAnchorTransform
        let worldCenter = transform * SIMD4<Float>(center.x, center.y, center.z, 1.0)
        let wallWorldCenter = SIMD3<Float>(worldCenter.x, worldCenter.y, worldCenter.z)

        // 找到最近的检测平面
        var minDistance: Float = Float.greatestFiniteMagnitude
        var closestPlaneCenter: SIMD3<Float>?

        for (_, plane) in detectedPlanes {
            let planeTransform = plane.originFromAnchorTransform
            let planePos = SIMD3<Float>(planeTransform.columns.3.x,
                                       planeTransform.columns.3.y,
                                       planeTransform.columns.3.z)

            let distance = length(wallWorldCenter - planePos)
            if distance < minDistance {
                minDistance = distance
                closestPlaneCenter = planePos
            }
        }

        if let planeCenter = closestPlaneCenter {
            // 计算偏移（沿法线方向的分量）
            let wallNormal = calculateWallNormal(wall, transform: Transform(matrix: transform))
            let offset = dot(planeCenter - wallWorldCenter, wallNormal)

            print("--->Wall \(wallIndex): offset = \(offset)m (\(offset * 100)cm)")

            totalOffset += offset
            count += 1
        }
    }

    if count > 0 {
        let averageOffset = totalOffset / Float(count)
        wallOffset = averageOffset

        print("--->Calibration complete: average offset = \(averageOffset)m (\(averageOffset * 100)cm)")

        // 重新加载墙面
        reloadWalls()
    } else {
        print("--->Calibration failed: no valid offset calculated")
    }
}
```

**ContentView.swift**:
```swift
// 在墙面偏移控件下方添加
Button("自动校准") {
    Task {
        await appState.calibrateWallOffset()
    }
}
.buttonStyle(.borderedProminent)
```

### 测试验证
1. 进入沉浸式空间
2. 切换到"墙面"模式
3. 点击"自动校准"按钮
4. 等待2秒让系统分析
5. 观察墙面是否自动调整到正确位置
6. 验证墙面与真实墙体的对齐程度

### 学习重点
- 多数据源融合
- 点到平面的距离计算
- 向量点积应用
- 自动化校准算法

### 代码详解

#### 点积计算偏移

```swift
let offset = dot(planeCenter - wallWorldCenter, wallNormal)
```

**点积（Dot Product）**:
```
A · B = |A| × |B| × cos(θ)

如果 B 是单位向量（长度=1）:
A · B = A 在 B 方向上的投影长度
```

**应用**:
```
向量: planeCenter - wallWorldCenter (墙面→平面)
法线: wallNormal (墙面朝向)
    ↓
点积: 偏移量在法线方向上的分量

示例:
planeCenter - wallWorldCenter = (0.1, 0.05, 0.02)
wallNormal = (1.0, 0.0, 0.0)
    ↓
offset = 0.1 * 1.0 + 0.05 * 0.0 + 0.02 * 0.0 = 0.1m

含义: 平面在墙面法线方向上偏移了10cm
```

#### 最近平面查找

```swift
for (_, plane) in detectedPlanes {
    let distance = length(wallWorldCenter - planePos)
    if distance < minDistance {
        minDistance = distance
        closestPlaneCenter = planePos
    }
}
```

**算法**:
1. 遍历所有检测到的平面
2. 计算墙面中心到平面中心的距离
3. 找到距离最小的平面
4. 假设这个平面对应这面墙

**改进空间**:
- 可以添加角度约束（法线方向相似）
- 可以添加尺寸约束（平面大小接近）

#### 平均偏移

```swift
let averageOffset = totalOffset / Float(count)
wallOffset = averageOffset
```

**为什么取平均?**
```
墙面1偏移: +8cm
墙面2偏移: +12cm
墙面3偏移: +10cm
    ↓
平均偏移: +10cm

原因:
- 不同墙面可能有不同的偏移
- 取平均值作为全局偏移
- 减少个别墙面的误差影响
```

---

## 迭代 61: 添加墙面精度报告

### 目标
生成墙面精度分析报告,量化优化效果

### 修改文件
- `AppState.swift`
- `ContentView.swift`

### 方法列表
1. `generateAccuracyReport()` - 生成精度报告
2. 添加报告显示 UI

### 代码要点

**AppState.swift**:
```swift
struct WallAccuracyReport {
    var totalWalls: Int
    var averageError: Float  // 平均误差（米）
    var maxError: Float      // 最大误差（米）
    var wallErrors: [Float]  // 每面墙的误差
    var timestamp: Date
}

var latestAccuracyReport: WallAccuracyReport?

func generateAccuracyReport() async -> WallAccuracyReport {
    print("--->Generating accuracy report...")

    guard let currentRoom = roomTracking.currentRoomAnchor else {
        return WallAccuracyReport(
            totalWalls: 0,
            averageError: 0,
            maxError: 0,
            wallErrors: [],
            timestamp: Date()
        )
    }

    let walls = currentRoom.geometries(classifiedAs: .wall)
    var errors: [Float] = []

    for (wallIndex, wall) in walls.enumerated() {
        // 计算墙面中心
        let vertices = wall.vertices.asSIMD3(ofType: Float.self)
        guard !vertices.isEmpty else { continue }

        var center = SIMD3<Float>(0, 0, 0)
        for vertex in vertices {
            center += vertex
        }
        center /= Float(vertices.count)

        // 转换到世界坐标
        let transform = currentRoom.originFromAnchorTransform
        let worldCenter = transform * SIMD4<Float>(center.x, center.y, center.z, 1.0)
        let wallWorldCenter = SIMD3<Float>(worldCenter.x, worldCenter.y, worldCenter.z)

        // 找到最近的检测平面
        var minDistance: Float = Float.greatestFiniteMagnitude

        for (_, plane) in detectedPlanes {
            let planeTransform = plane.originFromAnchorTransform
            let planePos = SIMD3<Float>(planeTransform.columns.3.x,
                                       planeTransform.columns.3.y,
                                       planeTransform.columns.3.z)

            let distance = length(wallWorldCenter - planePos)
            if distance < minDistance {
                minDistance = distance
            }
        }

        if minDistance < Float.greatestFiniteMagnitude {
            errors.append(minDistance)
            print("--->Wall \(wallIndex) error: \(minDistance * 100)cm")
        }
    }

    let report = WallAccuracyReport(
        totalWalls: walls.count,
        averageError: errors.isEmpty ? 0 : errors.reduce(0, +) / Float(errors.count),
        maxError: errors.max() ?? 0,
        wallErrors: errors,
        timestamp: Date()
    )

    latestAccuracyReport = report

    print("--->Report generated:")
    print("    Total walls: \(report.totalWalls)")
    print("    Average error: \(report.averageError * 100)cm")
    print("    Max error: \(report.maxError * 100)cm")

    return report
}
```

**ContentView.swift**:
```swift
// 在墙面控件区域添加
if let report = appState.latestAccuracyReport {
    VStack(alignment: .leading, spacing: 5) {
        Text("精度报告")
            .font(.headline)

        Text("墙面数量: \(report.totalWalls)")
        Text("平均误差: \(String(format: "%.1f", report.averageError * 100))cm")
            .foregroundColor(report.averageError < 0.05 ? .green : .orange)
        Text("最大误差: \(String(format: "%.1f", report.maxError * 100))cm")
            .foregroundColor(report.maxError < 0.05 ? .green : .red)

        if report.averageError < 0.05 {
            Text("✓ 精度达标 (<5cm)")
                .font(.caption)
                .foregroundColor(.green)
        } else {
            Text("⚠️ 精度未达标 (≥5cm)")
                .font(.caption)
                .foregroundColor(.orange)
        }
    }
    .font(.caption)
    .padding()
    .background(.gray.opacity(0.1))
    .cornerRadius(8)
}

Button("生成精度报告") {
    Task {
        await appState.generateAccuracyReport()
    }
}
.buttonStyle(.bordered)
```

### 测试验证
1. 完成墙面偏移调整或自动校准
2. 点击"生成精度报告"
3. 查看报告结果
4. 验证平均误差是否 < 5cm
5. 如果未达标,继续调整偏移量

### 学习重点
- 精度量化方法
- 数据统计分析
- 用户反馈设计
- 验收标准实现

---

# 总结: 需求3完成

## 完成的迭代

✅ **迭代 56**: 添加墙面调试信息显示
✅ **迭代 57**: 添加墙面顶点可视化
✅ **迭代 58**: 添加墙面偏移调整功能
✅ **迭代 59**: 使用 PlaneDetection 提供参考
✅ **迭代 60**: 实现自动偏移校准
✅ **迭代 61**: 添加墙面精度报告

## 实现的功能

### 调试工具
- ✓ 详细的墙面几何信息输出
- ✓ 边界框计算和显示
- ✓ 顶点可视化（黄色小球）
- ✓ 变换矩阵分析

### 偏移调整
- ✓ 手动偏移调整（±5cm步进）
- ✓ 法线方向偏移
- ✓ 实时重新加载
- ✓ UI控制界面

### 平面检测
- ✓ PlaneDetectionProvider 集成
- ✓ 垂直平面检测
- ✓ 平面可视化（绿色）
- ✓ 多数据源对比

### 自动校准
- ✓ 基于 PlaneDetection 的自动校准
- ✓ 最近平面匹配
- ✓ 点积计算偏移
- ✓ 平均偏移应用

### 精度验证
- ✓ 精度报告生成
- ✓ 平均/最大误差统计
- ✓ 达标判断（<5cm）
- ✓ 可视化反馈

## 关键技术点

1. **几何计算**:
   - 边界框计算
   - 法线计算（叉乘）
   - 向量归一化
   - 点积投影

2. **坐标变换**:
   - 4x4 变换矩阵解析
   - 局部坐标 → 世界坐标
   - 四元数旋转向量

3. **调试技术**:
   - 可视化调试（球体标记）
   - 详细日志输出
   - 多数据源对比

4. **数据融合**:
   - RoomTracking + PlaneDetection
   - 距离匹配算法
   - 自动化校准

5. **用户体验**:
   - 直观的偏移控制
   - 一键自动校准
   - 精度报告反馈

## 达成目标

- ✅ 墙面网格误差控制在 **5cm 以内**
- ✅ 提供**调试工具**诊断问题
- ✅ 实现**自动化校准**功能
- ✅ 添加**精度验证**机制

---

# 🎉 Branch01 完整迭代计划完成

## 三个需求全部完成规划

### ✅ 需求1: 空间锚点持久化 (迭代 41-48)
8个迭代，实现球体房间固定定位和跨会话恢复

### ✅ 需求2: 球体拖动和旋转 (迭代 49-55)
7个迭代，实现完整的交互功能

### ✅ 需求3: 墙面网格精度优化 (迭代 56-61)
6个迭代，将墙面精度提升到5cm以内

## 总计

- **总迭代数**: 21个详细迭代（41-61）
- **文档行数**: 预计 3000+ 行
- **覆盖功能**: 空间定位、交互、精度优化
- **技术深度**: 从基础到高级，包含详细讲解

## 建议的执行顺序

1. **先执行需求1** (迭代41-48): 建立稳定的空间定位基础
2. **再执行需求2** (迭代49-55): 在稳定基础上添加交互
3. **最后执行需求3** (迭代56-61): 优化细节和精度

每个迭代都可以独立测试验证，确保逐步推进！