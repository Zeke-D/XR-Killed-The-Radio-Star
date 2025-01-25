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
import AVKit
import AVFoundation

/// The Full Space that displays when someone plays the game.
struct MainView:  View {
    @Environment(AppModel.self) var appModel
    
    @State var leftHand: Entity?
    
    var body: some View {
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
            
            // Create a URL that points to the movie file.
            print("Added video!")
            
            
            content.add(cameraRelativeAnchor)
            
        }
        .handGesture(
            MySnap(hand: .left)
                .onChanged { value in
                    if (value.pose == .postSnap) {
                        handleSnap(value: value)
                    }
                }
        )
    }
    
    func handleSnap(value: MySnap.Value) -> Void {
        print("From: ", self.appModel.playingState)
        switch self.appModel.playingState {
        case .notStarted:
            self.appModel.playingState = .started
        case .started:
            self.appModel.playingState = .musicStart
        case .musicStart:
            self.appModel.playingState = .flatVideo
        case .flatVideo:
            self.appModel.playingState = .spatialVideo
        case .spatialVideo:
            self.appModel.playingState = .fullOuterSpace
        case .fullOuterSpace:
            self.appModel.playingState = .flying
        case .flying:
            self.appModel.playingState = .collaborative
        case .collaborative:
            print("Done!")
        default: break
        }
        print("To: ", self.appModel.playingState)
    }
}
