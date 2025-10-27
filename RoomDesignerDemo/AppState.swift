//
//  AppState.swift
//  RoomDesignerDemo
//
//  Created by Claude on 2025/10/27.
//

import Foundation
import Observation

@Observable
@MainActor
class AppState {
    // 是否在沉浸式空间中
    var isImmersive = false

    init() {
        print("AppState initialized")
    }
}
