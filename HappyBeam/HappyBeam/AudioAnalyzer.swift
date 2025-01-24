import Foundation
import AVFoundation
import Accelerate

public class AudioAnalyzer: ObservableObject {
    @Published public var amplitude: Float = 0.0
    @Published public var frequencies: [Float] = []
    @Published public var dominantFrequency: Float = 0.0
    
    private var audioFile: AVAudioFile?
    private var audioEngine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var lastAmplitude: Float = 0.0
    private let smoothingFactor: Float = 0.1 // Adjust this to control smoothing (0.0 to 1.0)
    
    // FFT setup
    private let fftSize = 1024
    private var fftSetup: FFTSetup?
    private var hannWindow: [Float] = []
    
    public init?(soundFile: String) {
        // Initialize FFT
        fftSetup = vDSP_create_fftsetup(vDSP_Length(log2(Float(fftSize))), FFTRadix(kFFTRadix2))
        
        // Create Hann window for better frequency analysis
        hannWindow = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&hannWindow, UInt(fftSize), Int32(vDSP_HANN_NORM))
        
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
            
            // Install tap on player for amplitude and frequency analysis
            player.installTap(onBus: 0, bufferSize: UInt32(fftSize), format: audioFile.processingFormat) { [weak self] buffer, time in
                guard let self = self else { return }
                
                // Get audio data
                guard let channelData = buffer.floatChannelData?[0] else { return }
                let frameLength = Int(buffer.frameLength)
                
                // Calculate amplitude (RMS)
                var sum: Float = 0
                for i in 0..<frameLength {
                    let sample = channelData[i]
                    sum += sample * sample
                }
                
                var rms = sqrt(sum / Float(frameLength))
                rms = min(1.0, rms * 10.0)
                
                // Apply amplitude smoothing
                let smoothedAmplitude = self.lastAmplitude + (rms - self.lastAmplitude) * self.smoothingFactor
                self.lastAmplitude = smoothedAmplitude
                
                // Prepare for FFT
                var realp = [Float](repeating: 0, count: self.fftSize/2)
                var imagp = [Float](repeating: 0, count: self.fftSize/2)
                var windowedData = [Float](repeating: 0, count: self.fftSize)
                
                // Safely copy and window the data
                let numSamples = min(frameLength, self.fftSize)
                for i in 0..<numSamples {
                    windowedData[i] = channelData[i] * self.hannWindow[i]
                }
                
                // If we have fewer samples than FFT size, zero-pad the rest
                if numSamples < self.fftSize {
                    for i in numSamples..<self.fftSize {
                        windowedData[i] = 0
                    }
                }
                
                // Create complex split array
                var complexBuffer = DSPSplitComplex(realp: &realp, imagp: &imagp)
                
                // Convert to split complex format
                windowedData.withUnsafeBytes { ptr in
                    guard let baseAddress = ptr.baseAddress?.bindMemory(to: DSPComplex.self, capacity: self.fftSize/2) else { return }
                    vDSP_ctoz(baseAddress,
                             2,
                             &complexBuffer,
                             1,
                             vDSP_Length(self.fftSize/2))
                }
                
                // Perform FFT
                guard let fftSetup = self.fftSetup else { return }
                vDSP_fft_zrip(fftSetup,
                             &complexBuffer,
                             1,
                             vDSP_Length(log2(Float(self.fftSize))),
                             FFTDirection(FFT_FORWARD))
                
                // Calculate magnitude spectrum
                var magnitudes = [Float](repeating: 0, count: self.fftSize/2)
                vDSP_zvmags(&complexBuffer, 1, &magnitudes, 1, vDSP_Length(self.fftSize/2))
                
                // Scale magnitudes
                var scaleFactor = Float(1.0/Float(self.fftSize))
                vDSP_vsmul(magnitudes, 1, &scaleFactor, &magnitudes, 1, vDSP_Length(self.fftSize/2))
                
                // Find dominant frequency
                var maxMagnitude: Float = 0
                var maxIndex: vDSP_Length = 0
                vDSP_maxvi(magnitudes, 1, &maxMagnitude, &maxIndex, vDSP_Length(self.fftSize/2))
                
                // Calculate frequency resolution (Hz per bin)
                let sampleRate = Float(audioFile.processingFormat.sampleRate)
                let binWidth = sampleRate / Float(self.fftSize)
                let dominantFreq = Float(maxIndex) * binWidth
                
                // Update published values on main thread
                DispatchQueue.main.async {
                    self.amplitude = smoothedAmplitude
                    self.frequencies = Array(magnitudes[0..<100]) // Only publish first 100 frequency bins
                    self.dominantFrequency = dominantFreq
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
        if let fftSetup = fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
        }
    }
} 