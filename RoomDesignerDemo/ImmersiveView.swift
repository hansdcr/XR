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

    var body: some View {
        RealityView { content in
            content.add(appState.contentRoot)
            print("--->Root entity added to scene")
        }
    }
}
