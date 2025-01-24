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
import HappyBeamAssets

/// The Full Space that displays when someone plays the game.
struct MainView:  View {
    @Environment(AppModel.self) var appModel
    
    @State var leftHand: Entity?
    
    var body: some View {
        VStack {
            RealityView { content in
                
                let configuration = SpatialTrackingSession.Configuration(
                                    tracking: [.hand])
                
                let session = SpatialTrackingSession()
                await session.run(configuration)
                self.leftHand = AnchorEntity(.hand(.left, location: .indexFingerTip))
                content.add(self.leftHand!)
//                let spawnedSphere = try! Entity.load(named: "xrk/AudioSphere", in: happyBeamAssetsBundle)
//                content.add(spawnedSphere)

                // The root entity.
                content.add(spaceOrigin)
                let spawnedSphere = try! Entity.load(named: "xrk/AudioSphere", in: happyBeamAssetsBundle)
                spaceOrigin.addChild(spawnedSphere)
                content.add(cameraRelativeAnchor)
                
                
            }
            .handGesture(
                MySnap(hand: .left)
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
                            let spawnedSphere = try! Entity.load(named: "xrk/AudioSphere", in: happyBeamAssetsBundle)
                            spawnedSphere.setPosition(value.position, relativeTo: nil)
                           
                            spaceOrigin.addChild(spawnedSphere)
                            
                            leftHand?.addChild(spawnedSphere)
                        }
                        print(appModel.leftStatus)
                    }
            )
            ToggleImmersiveSpaceButton()
        }
    }
}
