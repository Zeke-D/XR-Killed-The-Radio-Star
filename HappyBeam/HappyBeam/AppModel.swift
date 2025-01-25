import SwiftUI
import RealityKit
import AVFoundation
import AVKit

/// Maintains app-wide state
/// 
@MainActor
@Observable
class AppModel {
    var gesture: HandGestures = .clapping
    var leftStatus: String = "---"
    var rightStatus: String = "---"

    let immersiveSpaceID = "mainView"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed
    
    
    enum PlayingState {
        case notStarted
        case started
        case spotlight
        case musicStart
        case flatVideo
        case spatialVideo
        case fullOuterSpace
        case flying
        case collaborative
    }
    
    var playingState = PlayingState.notStarted
    
    var movieScene = Entity()
    
    func handleSnap(value: MySnap.Value) -> Void {
        print("From: ", self.playingState)
        switch self.playingState {
        case .notStarted:
            self.drawMovieScene()
            self.playingState = .started
        case .started:
            self.playingState = .musicStart
        case .musicStart:
            self.playingState = .flatVideo
        case .flatVideo:
            self.playingState = .spatialVideo
        case .spatialVideo:
            self.playingState = .fullOuterSpace
        case .fullOuterSpace:
            self.playingState = .flying
        case .flying:
            self.playingState = .collaborative
        case .collaborative:
            print("Done!")
        default: break
        }
        print("To: ", self.playingState)
    }

    func drawMovieScene() {
        self.movieScene.setPosition(SIMD3(0, 0, -2.5), relativeTo: spaceOrigin)
        let movieScreen = self.movieScene.findEntity(named: "Screen")!
        let url = Bundle.main.url(forResource: "concert", withExtension: "MOV")!
        let player = AVPlayer(url: url)
        player.isMuted = true; // no sound of concert
        let material = VideoMaterial(avPlayer: player)
        movieScreen.modelComponent!.materials = [material]
        player.play()
        spaceOrigin.addChild(movieScene)
    }
    
}
