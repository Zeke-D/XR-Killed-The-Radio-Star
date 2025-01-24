//
//  OrbController.swift
//  SpatialAudio
//
//  Created by IVAN CAMPOS on 1/22/25.
//


import RealityKit
import Combine

class OrbController: ObservableObject {
    @Published var isPlaying: Bool = false
    private var playbackController: AudioPlaybackController?
    
    let orb: ModelEntity
    let audioSource = Entity()
    
    init(soundFile: String, x: Float, y: Float, z: Float) {
        // Create the base orb
        self.orb = ModelEntity(
            mesh: .generateSphere(radius: 0.1),
            materials: [SimpleMaterial(color: .white, isMetallic: false)]
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
        
        // Pre-load the audio resource
        loadAudio(soundFile: soundFile)
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
        } catch {
            print("Error loading audio file:", error.localizedDescription)
        }
    }
    
    func toggleAudio() {
        guard let controller = playbackController else { return }
        
        if isPlaying {
            // If pause() is not working on your setup, try stop()
            controller.pause()
            // controller.stop() // <- Uncomment this if pause() fails in your environment
        } else {
            controller.play()
        }
        isPlaying.toggle()
        
        print("OrbController.toggleAudio() -> isPlaying:", isPlaying)
    }
}
