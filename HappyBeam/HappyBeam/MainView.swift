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
    
    var body: some View {
        RealityView { content in
            
            let configuration = SpatialTrackingSession.Configuration(
                                tracking: [.hand])
            
            let session = SpatialTrackingSession()
            await session.run(configuration)
            content.add(spaceOrigin)
            content.add(cameraRelativeAnchor)
            let movieScene = try! await Entity(named: "xrk/MovieScene", in: happyBeamAssetsBundle)
            movieScene.setPosition(SIMD3(0, -1, -1), relativeTo: spaceOrigin)
            movieScene.findEntity(named: "Player")?.isEnabled = false
            spaceOrigin.addChild(movieScene)
            appModel.movieScene = movieScene
            
        }
        .handGesture(
            MySnap(hand: .left)
                .onChanged { value in
                    print(value.pose)
                    if (value.pose == .postSnap) {
                        handleSnap(value: value)
                    }
                }
        )
        ToggleImmersiveSpaceButton()
    }
    
    func handleSnap(value: MySnap.Value) -> Void {
        print("From: ", self.appModel.playingState)
        switch self.appModel.playingState {
        case .notStarted:
            self.appModel.playingState = .started
            self.appModel.movieScene?.findEntity(named: "Player")?.isEnabled = true
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
