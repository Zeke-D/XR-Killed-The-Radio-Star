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
    @State private var reverb: ZitaReverb?
    @State private var mixer = Mixer()
    @State private var reverbMix: Float = 0.0
    @State private var timer: Timer?
    @State private var isAudioSetup = false
    
    var body: some View {
        RealityView { content in
            // Set up audio player and reverb
            do {
//                if let soundURL = Bundle.main.url(forResource: "10TO3KSWEEP", withExtension: "wav") {
                if let soundURL = Bundle.main.url(forResource: "MONOSTEM", withExtension: "mp3") {
                    player = AudioPlayer(url: soundURL)
                    if let player = player {
                        reverb = ZitaReverb(
                            player,
                            predelay: 60,              // 60ms predelay
                            crossoverFrequency: 200,    // Crossover between low/mid
                            lowReleaseTime: 3,         // Bass reverb time
                            midReleaseTime: 2,         // Mid frequency reverb time
                            dampingFrequency: 6000,    // High frequency damping
                            equalizerFrequency1: 315,  // First EQ frequency
                            equalizerLevel1: 0,        // First EQ level (dB)
                            equalizerFrequency2: 1500, // Second EQ frequency
                            equalizerLevel2: 0,        // Second EQ level (dB)
                            dryWetMix: reverbMix       // Start dry
                        )
                        
                        if let reverb = reverb {
                            engine.output = reverb
                            
                            // Create timer to toggle reverb with smoother transitions
                            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak reverb] _ in
                                guard let reverb = reverb else { return }
                                if reverbMix == 0.0 && reverb.dryWetMix < 0.7 {
                                    // Gradually increase reverb
                                    reverb.dryWetMix += 0.05
                                    if reverb.dryWetMix >= 0.7 {
                                        reverbMix = 0.7
                                    }
                                } else if reverbMix == 0.7 && reverb.dryWetMix > 0.0 {
                                    // Gradually decrease reverb
                                    reverb.dryWetMix -= 0.05
                                    if reverb.dryWetMix <= 0.0 {
                                        reverbMix = 0.0
                                    }
                                }
                            }
                            
                            try engine.start()
                            player.play()
                            isAudioSetup = true
                        }
                    }
                }
            } catch {
                print("Failed to load audio file: \(error)")
            }
            
            let configuration = SpatialTrackingSession.Configuration(
                                tracking: [.hand])
            
            let session = SpatialTrackingSession()
            await session.run(configuration)
            content.add(spaceOrigin)
            content.add(cameraRelativeAnchor)
            
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
        .onDisappear {
            // Clean up timer when view disappears
            timer?.invalidate()
            timer = nil
        }
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
