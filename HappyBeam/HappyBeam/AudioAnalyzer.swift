import Foundation
import AVFoundation
import Accelerate

public class AudioAnalyzer: ObservableObject {
    @Published public var amplitude: Float = 0.0
    @Published public var dominantFrequency: Float = 0.0
    
    private var audioFile: AVAudioFile?
    private var audioEngine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var lastAmplitude: Float = 0.0
    private let smoothingFactor: Float = 0.1 // Adjust this to control smoothing (0.0 to 1.0)
    
    // FFT setup - using power of 2 for optimal performance
    private let fftSize = 1024  // 2^10
    private var fftSetup: FFTSetup?
    
    // Pre-allocated buffers for FFT processing
    private var hannWindow: [Float]
    private var realBuffer: UnsafeMutablePointer<Float>
    private var imagBuffer: UnsafeMutablePointer<Float>
    private var splitComplex: DSPSplitComplex
    private let log2n: UInt
    
    // Reusable magnitude buffer
    private var magnitudeBuffer: UnsafeMutablePointer<Float>
    
    // Audio file scheduling
    private var isLooping: Bool = true
    private var scheduledFile: AVAudioFile?
    
    public init?(soundFile: String) {
        // Initialize FFT buffers and setup
        log2n = UInt(log2(Float(fftSize)))
        
        // Allocate all buffers
        realBuffer = .allocate(capacity: fftSize/2)
        imagBuffer = .allocate(capacity: fftSize/2)
        magnitudeBuffer = .allocate(capacity: fftSize/2)
        splitComplex = DSPSplitComplex(realp: realBuffer, imagp: imagBuffer)
        
        // Create and cache Hann window
        hannWindow = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&hannWindow, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        
        // Create FFT setup
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            print("Failed to create FFT setup")
            return nil
        }
        fftSetup = setup
        
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
            
            audioEngine.attach(player)
            audioEngine.connect(player, to: audioEngine.mainMixerNode, format: audioFile.processingFormat)
            
            // Install tap for analysis
            player.installTap(onBus: 0, bufferSize: UInt32(fftSize), format: audioFile.processingFormat) { [weak self] buffer, time in
                guard let self = self else { return }
                self.processBuffer(buffer)
            }
            
            try audioEngine.start()
            
        } catch {
            print("Failed to initialize audio analyzer:", error.localizedDescription)
            return nil
        }
    }
    
    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        // Use vDSP for RMS calculation
        var rms: Float = 0
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameLength))
        rms = min(1.0, rms * 10.0)
        
        // Apply amplitude smoothing
        let smoothedAmplitude = lastAmplitude + (rms - lastAmplitude) * smoothingFactor
        lastAmplitude = smoothedAmplitude
        
        // Apply Hann window using vDSP
        var windowedData = [Float](repeating: 0, count: fftSize)
        let analysisCount = min(frameLength, fftSize)
        
        // Copy only the data we need
        memcpy(&windowedData, channelData, analysisCount * MemoryLayout<Float>.stride)
        
        // Apply window in-place
        vDSP_vmul(windowedData, 1, hannWindow, 1, &windowedData, 1, vDSP_Length(fftSize))
        
        // Convert to split complex format with stride
        windowedData.withUnsafeBytes { ptr in
            guard let baseAddr = ptr.baseAddress else { return }
            vDSP_ctoz(baseAddr.assumingMemoryBound(to: DSPComplex.self),
                     2,
                     &splitComplex,
                     1,
                     vDSP_Length(fftSize/2))
        }
        
        // Perform FFT in-place
        guard let fftSetup = fftSetup else { return }
        vDSP_fft_zrip(fftSetup,
                      &splitComplex,
                      1,
                      log2n,
                      FFTDirection(FFT_FORWARD))
        
        // Calculate magnitude spectrum in-place
        vDSP_zvmags(&splitComplex, 1, magnitudeBuffer, 1, vDSP_Length(fftSize/2))
        
        // Scale magnitudes
        var scaleFactor = 1.0 / Float(fftSize)
        vDSP_vsmul(magnitudeBuffer, 1, &scaleFactor, magnitudeBuffer, 1, vDSP_Length(fftSize/2))
        
        // Find dominant frequency
        var maxMagnitude: Float = 0
        var maxIndex: vDSP_Length = 0
        vDSP_maxvi(magnitudeBuffer, 1, &maxMagnitude, &maxIndex, vDSP_Length(fftSize/2))
        
        // Calculate frequency
        let sampleRate = Float(buffer.format.sampleRate)
        let binWidth = sampleRate / Float(fftSize)
        let dominantFreq = Float(maxIndex) * binWidth
        
        // Update published values on main thread
        DispatchQueue.main.async {
            self.amplitude = smoothedAmplitude
            self.dominantFrequency = dominantFreq
        }
    }
    
    public func startAnalysis() {
        guard let audioFile = audioFile,
              let player = player else { return }
        
        // Schedule the initial playback
        scheduleNextPlayback()
        player.play()
    }
    
    private func scheduleNextPlayback() {
        guard let audioFile = audioFile,
              let player = player else { return }
        
        // Schedule the file to play
        player.scheduleFile(audioFile, at: nil) { [weak self] in
            // This completion handler is called when the file finishes playing
            guard let self = self, self.isLooping else { return }
            
            // Schedule the next playback on the main thread
            DispatchQueue.main.async {
                self.scheduleNextPlayback()
            }
        }
    }
    
    public func stopAnalysis() {
        isLooping = false
        player?.stop()
    }
    
    deinit {
        player?.removeTap(onBus: 0)
        audioEngine?.stop()
        
        // Clean up FFT resources
        if let fftSetup = fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
        }
        
        // Free allocated memory
        realBuffer.deallocate()
        imagBuffer.deallocate()
        magnitudeBuffer.deallocate()
    }
} 