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
import SoundpipeAudioKit
import AudioKit

/// The Full Space that displays when someone plays the game.
struct MainView:  View {
    @Environment(AppModel.self) var appModel
    @State private var engine = AudioEngine()
    @State private var player: AudioPlayer?
    @State private var timer: Timer?
    
    let root = Entity()
    @State private var testCustomAudio : CustomAudioSource? = nil
    
    var body: some View {
        RealityView { content in
            
            // Example of loading audio file:
            //            let soundURL = Bundle.main.url(forResource: "10TO3KSWEEP", withExtension: "wav")!
            //            player = AudioPlayer(url: soundURL)
            
            content.add(spaceOrigin)
            content.add(root)
            
            content.add(cameraRelativeAnchor)
            let addExampleAudioEntity = false
            if addExampleAudioEntity {
                let exampleAudioEntity = Entity()
                // Modify the entity here with location, gain, etc.
                testCustomAudio = CustomAudioSource(entity: exampleAudioEntity)
                // This can be any AudioKit node!
                testCustomAudio?.setSource(source: WhiteNoise())
                testCustomAudio?.start()
                root.addChild(exampleAudioEntity)
            }
            
            let movieScene = try! await Entity(named: "xrk/MovieScene", in: happyBeamAssetsBundle)
            appModel.movieScene = movieScene
            MovieSystem.registerSystem()
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
        Button("SNAP", action: {
            self.appModel.handleSnap(value: MySnap.Value(pose: .postSnap, chirality: .left, position: SIMD3()))
        }).scaleEffect(5)
    }
}
