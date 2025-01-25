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
//            //            movieScene.findEntity(named: "Player")!.isEnabled = false
            movieScene.setPosition(SIMD3(0, 0, -2.5), relativeTo: spaceOrigin)
            spaceOrigin.addChild(movieScene)
            appModel.movieScene = movieScene
            
            let movieScreen = movieScene.findEntity(named: "Screen")!
            
            let url = Bundle.main.url(forResource: "concert", withExtension: "MOV")!
            let player = AVPlayer(url: url)
            let material = VideoMaterial(avPlayer: player)
            movieScene.findEntity(named: "Screen")!.modelComponent!.materials = [material]


            // Start playing the video.
            player.play()
            

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
        .onChange(of: self.appModel.playingState, { old, new in
            
        })
        if self.appModel.playingState != .notStarted {
//            PlayerView()
        }
        Button("SNAP", action: {
            handleSnap(value: MySnap.Value(pose: .postSnap, chirality: .left, position: SIMD3()))
        }).scaleEffect(5)
    }
    
    func handleSnap(value: MySnap.Value) -> Void {
        print("From: ", self.appModel.playingState)
        switch self.appModel.playingState {
        case .notStarted:
            self.appModel.playingState = .started
//            self.appModel.movieScene!.findEntity(named: "Player")!.isEnabled = true
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
