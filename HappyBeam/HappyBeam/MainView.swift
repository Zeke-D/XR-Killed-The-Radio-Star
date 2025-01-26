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
    
    @State private var testCustomAudio : CustomAudioSource? = nil
    
    var body: some View {
        RealityView { content in
            
            // Example of loading audio file:
            //            let soundURL = Bundle.main.url(forResource: "10TO3KSWEEP", withExtension: "wav")!
            //            player = AudioPlayer(url: soundURL)
            
            content.add(spaceOrigin)
            content.add(appModel.root)
            
            content.add(cameraRelativeAnchor)
            let addExampleAudioEntity = false
            if addExampleAudioEntity {
                let exampleAudioEntity = Entity()

                appModel.root.addChild(exampleAudioEntity)
                exampleAudioEntity.components.set(SpatialAudioComponent())
                // Modify the entity here with location, gain, etc.
                testCustomAudio = CustomAudioSource(entity: exampleAudioEntity)
                // This can be any AudioKit node!
                let square = Oscillator(waveform: Table(.square), amplitude: 0.1)
                testCustomAudio?.setSource(source: square)
                testCustomAudio?.start()
            }
            
            let movieScene = try! await Entity(named: "xrk/MovieScene", in: happyBeamAssetsBundle)
            appModel.movieScene = movieScene
            
            let rocketScene = try! await Entity(named: "xrk/Rocket", in: happyBeamAssetsBundle)
            appModel.rocketScene = rocketScene
            
            let particleScene = try! await Entity(named: "xrk/particle", in: happyBeamAssetsBundle)
            appModel.snapParticle = particleScene.findEntity(named: "SnapParticle")!;

            AnimationSystem.registerSystem()
            AsteroidSystem.registerSystem()
            
            self.appModel.drawMovieScene()
            self.appModel.playingState = .inTheater
        }
        .handGesture(
            MySnap(hand: .left)
                .onChanged { value in
                    if (value.pose == .postSnap) {
                        self.appModel.handleSnap(value: value)
                    }
                }
        )
        .handGesture(
            MySnap(hand: .right)
                .onChanged { value in
                    if (value.pose == .postSnap) {
                        self.appModel.handleSnap(value: value)
                    }
                }
        )
        .gesture(TapGesture()
            .targetedToEntity(where: .has(AsteroidComponent.self))
            .onEnded({ val in
                if appModel.grabbedEntity != nil {
                    if appModel.grabbedEntity == val.entity {
                        if val.entity.components.has(EltonComponent.self) {
                            // Just remove grabbed component and keep current scale
                            val.entity.components.remove(GrabbedComponent.self)
                            appModel.asteroid_container.addChild(val.entity)
                            appModel.grabbedEntity = nil
                        } else {
                            val.entity.components.remove(GrabbedComponent.self)
                            appModel.asteroid_container.addChild(val.entity)
                            appModel.grabbedEntity = nil
                            val.entity.setScale(val.entity.scale * 3.0, relativeTo: val.entity.parent)
                        }
                    }
                    return
                }
                
                // Handle grabbing
                val.entity.components.set(GrabbedComponent())
                appModel.rightIndex.addChild(val.entity)
                val.entity.setPosition(SIMD3(), relativeTo: val.entity.parent)
                appModel.grabbedEntity = val.entity
                
                if val.entity.components.has(EltonComponent.self) {
                    // Scale only the Y component while maintaining position
                    let currentScale = val.entity.scale
                    val.entity.setScale(SIMD3<Float>(
                        currentScale.x,
                        currentScale.y * 1.3,
                        currentScale.z
                    ), relativeTo: val.entity.parent)
                } else {
                    val.entity.setScale(val.entity.scale / 3.0, relativeTo: val.entity.parent)
                }
            })
        )
        Button("SNAP", action: {
            self.appModel.handleSnap(value: MySnap.Value(pose: .postSnap, chirality: .left, position: SIMD3()))
        }).scaleEffect(5)
    }
}
