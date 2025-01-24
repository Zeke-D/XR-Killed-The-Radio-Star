import Foundation
import AVFoundation

public class AudioAnalyzer: ObservableObject {
    @Published public var amplitude: Float = 0.0
    
    private var audioFile: AVAudioFile?
    private var audioEngine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var lastAmplitude: Float = 0.0
    private let smoothingFactor: Float = 0.1 // Adjust this to control smoothing (0.0 to 1.0)
    
    public init?(soundFile: String) {
        guard let url = Bundle.main.url(forResource: soundFile, withExtension: nil) else {
            print("Could not find sound file:", soundFile)
            return nil
        }
        
        do {
            audioFile = try AVAudioFile(forReading: url)
            audioEngine = AVAudioEngine()
            player = AVAudioPlayerNode()
            
            guard let audioFile = audioFile,
                  let audioEngine = audioEngine,
                  let player = player else { return nil }
            
            // Set up audio engine
            audioEngine.attach(player)
            audioEngine.connect(player, to: audioEngine.mainMixerNode, format: audioFile.processingFormat)
            
            // Install tap on player for amplitude analysis
            player.installTap(onBus: 0, bufferSize: 1024, format: audioFile.processingFormat) { [weak self] buffer, time in
                guard let self = self else { return }
                
                // Calculate RMS (Root Mean Square) amplitude
                let channelData = buffer.floatChannelData?[0]
                let frameLength = UInt(buffer.frameLength)
                
                var sum: Float = 0
                for i in 0..<frameLength {
                    let sample = channelData?[Int(i)] ?? 0
                    sum += sample * sample
                }
                
                var rms = sqrt(sum / Float(frameLength))
                
                // Normalize RMS to 0.0-1.0 range (typical audio RMS values are very small)
                rms = min(1.0, rms * 10.0)
                
                // Apply smoothing
                let smoothedAmplitude = self.lastAmplitude + (rms - self.lastAmplitude) * self.smoothingFactor
                self.lastAmplitude = smoothedAmplitude
                
                DispatchQueue.main.async {
                    self.amplitude = smoothedAmplitude
                }
            }
            
            try audioEngine.start()
            
        } catch {
            print("Failed to initialize audio analyzer:", error.localizedDescription)
            return nil
        }
    }
    
    public func startAnalysis() {
        guard let audioFile = audioFile,
              let player = player else { return }
        
        player.scheduleFile(audioFile, at: nil, completionHandler: nil)
        player.play()
    }
    
    public func stopAnalysis() {
        player?.stop()
    }
    
    deinit {
        player?.removeTap(onBus: 0)
        audioEngine?.stop()
    }
} 