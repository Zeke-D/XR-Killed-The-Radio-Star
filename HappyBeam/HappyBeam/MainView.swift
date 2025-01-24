//
//  MainView.swift
//  HappyBeam
//
//  Created by Zeke D'Ascoli on 1/24/25.
//  Copyright © 2025 Apple. All rights reserved.
//
import RealityKit
import SwiftUI
import HandGesture

/// The Full Space that displays when someone plays the game.
struct MainView:  View {
    @Environment(AppModel.self) var appModel
    
    @StateObject private var controller: OrbController
    
    init(soundFile: String, x: Float, y: Float, z: Float) {
        // Initialize our OrbController here
        _controller = StateObject(wrappedValue: OrbController(
            soundFile: soundFile,
            x: x,
            y: y,
            z: z
        ))
    }
    
    
    var body: some View {
        VStack {
            RealityView { content in
                // The root entity.
//                content.add(spaceOrigin)
//                content.add(cameraRelativeAnchor)
                content.add(controller.orb)
                
                
            }
            .handGesture(
                SnapGesture(hand: .left)
                    .onChanged { value in
                        print(value.pose == .postSnap ? "L post snap" : "L pre snap")
                        guard appModel.gesture == HandGestures.snap else { return }
                        switch value.pose {
                        case .noSnap:
                            appModel.leftStatus = "---"
                        case .preSnap:
                            appModel.leftStatus = "🫰"
                        case .postSnap:
                            appModel.leftStatus = "snap"
                        }
                        print(appModel.leftStatus)
                    }
            )
            ToggleImmersiveSpaceButton()
        }
    }
}
