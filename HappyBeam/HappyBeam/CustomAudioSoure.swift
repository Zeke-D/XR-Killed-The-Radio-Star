//
//  CustomAudioSource.swift
//  HappyBeam
//
//  Created by Kevin King on 1/25/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import AudioKit
import AVFoundation
import RealityKit

/// Creates an engine and entity that can be used to play generate audio from the entity
class CustomAudioSource {
    let engine = AudioEngine()
    private var input : (any Node)? = nil
    let entity : Entity
    var controller: AudioGeneratorController? = nil
    
    init(entity: Entity) {
        self.entity = entity
        try? engine.avEngine.enableManualRenderingMode(.offline, format: .init(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 1, interleaved: true)!, maximumFrameCount: 512)
        engine.outputAudioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 1, interleaved: true)!
        
        let config = AudioGeneratorConfiguration(layoutTag: kAudioChannelLayoutTag_Mono)
        if let controller = try? entity.prepareAudio(configuration: config, Self.createCustomBlock(engine: engine)) {
            self.controller = controller
        }
    }
    
    func setSource(source: any Node) {
        self.input = source
        engine.output = source
    }
    
    @MainActor
    func start() {
        try? self.engine.start()
        self.input?.play()
        self.controller?.play()
    }
    
    @MainActor
    func stop() {
        self.controller?.stop()
        self.input?.stop()
        self.engine.stop()
    }
    
    private static func createCustomBlock(engine: AudioEngine) -> AVAudioSourceNodeRenderBlock {
        let SAMPLE_RATE = 48000.0
        let block: AVAudioSourceNodeRenderBlock = { isSilence, timestamp, frameCount, outputData in
            
            let buffer = UnsafeMutableAudioBufferListPointer(outputData)[0]
            let ptr = buffer.mData?.assumingMemoryBound(to: Float.self)
            
            let pcm = engine.render(duration: Double(frameCount) * (1.0 / SAMPLE_RATE))
            guard let floatdata = pcm.floatChannelData else {
                print("no float channel data")
                return noErr
            }
            for i in 0..<Int(frameCount) {
                ptr![i] = Float(floatdata[0][i])
            }
            
            return noErr
        }
        
        return block

    }
}
