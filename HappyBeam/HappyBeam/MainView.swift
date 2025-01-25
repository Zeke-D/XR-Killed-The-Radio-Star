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
            
            content.add(spaceOrigin)
            
            let movieScene = try! await Entity(named: "xrk/MovieScene", in: happyBeamAssetsBundle)
            appModel.movieScene = movieScene
        }
        .handGesture(
            MySnap(hand: .left)
                .onChanged { value in
                    print(value.pose)
                    if (value.pose == .postSnap) {
                        self.appModel.handleSnap(value: value)
                    }
                }
        )
        .onChange(of: self.appModel.playingState, { old, new in
            
        })
        if self.appModel.playingState != .notStarted {
//            PlayerView()
        }
        Button("SNAP", action: {
            self.appModel.handleSnap(value: MySnap.Value(pose: .postSnap, chirality: .left, position: SIMD3()))
        }).scaleEffect(5)
    }
}
