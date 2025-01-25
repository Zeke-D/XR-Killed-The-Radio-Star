import SwiftUI
import RealityKit
import AVFoundation
import AVKit

class MovieComponent : Component {
    var duration : Double = 1.0
    var progress : Double = 0
    var delay : Double = 0
    var start_pos : SIMD3<Float> = SIMD3()
    var target_pos : SIMD3<Float> = SIMD3()
    var calledStartTrigger : Bool = false
    var calledEndTrigger : Bool = false

    enum AnimationState {
        case pre
        case started
        case ended
    }
    
    var state: AnimationState = .pre
    var onStart: () -> Void = {} // option callback to trigger when started
    var onEnd: () -> Void = {} // option callback to trigger when ended
    func play() { self.state = .started }
}


class MovieSystem : System {
    private static let query = EntityQuery(where: .has(MovieComponent.self))

    required init(scene: RealityKit.Scene) { }

    func update(context: SceneUpdateContext) {
       for entity in context.entities(
           matching: Self.query,
           updatingSystemWhen: .rendering
       ) {
           var mc = entity.components[MovieComponent.self]!
           if mc.state != .started { continue }
           mc.progress += context.deltaTime
           
           // call start handler
           if (!mc.calledStartTrigger && mc.progress > mc.delay) {
               mc.onStart()
               mc.calledStartTrigger = true
           }
           
           // finish. Should only call once because of clause earlier!
           if (mc.progress > mc.duration + mc.delay) {
               mc.state = .ended
               mc.onEnd()
           }
           else {
               let pct = Float(max((mc.progress - mc.delay), 0) / mc.duration);
               let new_pos = SIMD3<Float>(pct, pct, pct) * (mc.target_pos - mc.start_pos);
               entity.setPosition(new_pos, relativeTo: nil)
           }
           
           entity.components.set(mc)
           
       }
    }
}

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
        case inTheater
        case musicStart
        case flatVideo
        case spatialVideo
        case fullOuterSpace
        case flying
        case collaborative
    }
    
    var playingState = PlayingState.notStarted
    
    var movieScene = Entity()
    var mainTrackEntity = Entity()
    
    func handleSnap(value: MySnap.Value) -> Void {
        print("From: ", self.playingState)
        switch self.playingState {
        case .notStarted:
            self.drawMovieScene()
            self.playingState = .inTheater
        case .inTheater:
            self.dimLightsAndPlayMusic()
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
    
    func dimLightsAndPlayMusic() {
        // dim lights
        print("Dimming lights")
        let scene = self.movieScene.scene!
        scene.performQuery(
            EntityQuery(where: .has(PointLightComponent.self))
        ).forEach { light in
            let pointComponent = PointLightComponent(
                color: PointLightComponent.Color(
                    hue: 80,
                    saturation: 0.1,
                    brightness: 1.0,
                    alpha: 1.0
                ),
                intensity: 0
            )
            light.components.set(pointComponent)
        }
        
        let mainTrackSound = try! AudioFileResource.load(named: "Rocketman")
        self.mainTrackEntity.orientation = .init(angle: .pi, axis: [0, 1, 0])
        self.mainTrackEntity.spatialAudio = SpatialAudioComponent()
        
        var screen = self.movieScene.findEntity(named: "Screen")!
        screen.addChild(self.mainTrackEntity)
        self.mainTrackEntity.playAudio(mainTrackSound)
        print("Playing audio")
        
        
        // play movie after delay
        var mc = MovieComponent()
        mc.onStart = self.playMovie
        mc.delay = 5
        mc.duration = 0.1
        mc.play()
        mc.onEnd = {
            var move = MovieComponent()
            print("Calling TV Move component")
            move.start_pos = screen.position
            move.target_pos = screen.position + SIMD3<Float>(0, 0, 10)
            move.duration = 10
            move.delay = 0
            move.play()
            self.movieScene.components.set(move)
        }
        self.movieScene.components.set(mc)
    }
    
    func drawMovieScene() {
        self.movieScene.setPosition(SIMD3(0, 0, -2.5), relativeTo: spaceOrigin)
        spaceOrigin.addChild(movieScene)
    }
    
    func playMovie() {
        let movieScreen = self.movieScene.findEntity(named: "Screen")!
        let url = Bundle.main.url(forResource: "concert", withExtension: "MOV")!
        let player = AVPlayer(url: url)
        player.isMuted = true; // no sound of concert
        let material = VideoMaterial(avPlayer: player)
        movieScreen.modelComponent!.materials = [material]
        player.play()
    }
    
}
