//
//  OrbController.swift
//  SpatialAudio
//
//  Created by IVAN CAMPOS on 1/22/25.
//


import SwiftUI
import RealityKit
import Combine
import AVFoundation


class OrbController: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var audioAmplitude: Float = 0.0
    private var playbackController: AudioPlaybackController?
    private var audioAnalyzer: AudioAnalyzer?
    private var cancellables = Set<AnyCancellable>()
    
    let orb: ModelEntity
    let audioSource = Entity()
    
    init(soundFile: String, x: Float, y: Float, z: Float) {
        // Create the base orb
        self.orb = ModelEntity(
            mesh: .generateSphere(radius: 0.1),
            materials: [SimpleMaterial(color: .white, isMetallic: true)]
        )
        
        // Position, collisions, etc.
        orb.position = SIMD3<Float>(x, y, z)
        orb.components.set(InputTargetComponent())
        orb.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.1)]))
        orb.components.set(GroundingShadowComponent(castsShadow: true))
        
        // Optional: Give the orb a name for debug prints.
        orb.name = "SoundOrb(\(soundFile))"
        
        // Create the audio holder
        audioSource.spatialAudio = SpatialAudioComponent()
        orb.addChild(audioSource)
        
        // Initialize audio analyzer
        audioAnalyzer = AudioAnalyzer(soundFile: soundFile)
        
        // Subscribe to amplitude changes
        audioAnalyzer?.$amplitude
            .receive(on: DispatchQueue.main)
            .sink { [weak self] amplitude in
                self?.updateOrbAppearance(amplitude: amplitude)
            }
            .store(in: &cancellables)
        
        // Pre-load the audio resource
        loadAudio(soundFile: soundFile)
    }
    
    private func updateOrbAppearance(amplitude: Float) {
        // Update scale based on amplitude (add a small base scale)
        let scale = 1.0 + amplitude * 1.5 // Reduced from 2.0 to 1.5 since amplitude is now normalized
        orb.scale = SIMD3<Float>(scale, scale, scale)
        
        // Update color based on amplitude
        let intensity = amplitude // No need to multiply since amplitude is already normalized
        if var material = orb.model?.materials.first as? SimpleMaterial {
            material.color = .init(tint: .init(
                red: CGFloat(1.0),
                green: CGFloat(1.0 - intensity),
                blue: CGFloat(1.0 - intensity),
                alpha: 1.0
            ))
            orb.model?.materials = [material]
        }
    }
    
    private func loadAudio(soundFile: String) {
        do {
            let resource = try AudioFileResource.load(
                named: soundFile,
                configuration: .init(shouldLoop: true)
            )
            // Begin playing immediately
            playbackController = audioSource.playAudio(resource)
            isPlaying = true
            audioAnalyzer?.startAnalysis()
        } catch {
            print("Error loading audio file:", error.localizedDescription)
        }
    }
    
    func toggleAudio() {
        guard let controller = playbackController else { return }
        
        if isPlaying {
            controller.pause()
            audioAnalyzer?.stopAnalysis()
        } else {
            controller.play()
            audioAnalyzer?.startAnalysis()
        }
        isPlaying.toggle()
        
        print("OrbController.toggleAudio() -> isPlaying:", isPlaying)
    }
}
