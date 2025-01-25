//
//  HandGestures.swift
//  HappyBeam
//
//  Created by Zeke D'Ascoli on 1/24/25.
//  Copyright © 2025 Apple. All rights reserved.
//


//
//  ContentView.swift
//  HandGestureApp
//
//  Created by John Haney on 12/8/24.
//

import SwiftUI
import RealityKit
import HandGesture

enum HandGestures: String, Hashable, Identifiable, CaseIterable {
    case clapping = "Clapping"
    case fingerGun = "Finger Guns"
    case sphere = "Holding Sphere"
    case punch = "Punching"
    case snap = "Snap"
    
    var id: String { rawValue }
}

extension HandGestures {
    var text: String {
        switch self {
        case .clapping:
            "👏"
        case .fingerGun:
            "👉👉"
        case .sphere:
            "🤲"
        case .punch:
            "👊"
        case .snap:
            "🫰"
        }
    }
}

struct ContentView: View {
    @Environment(AppModel.self) var appModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ToggleImmersiveSpaceButton()
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
}
