import SwiftUI
import RealityKit
import AVFoundation
import AVKit

class Animation {
    var start_time: Double = 0
    var duration : Double = 1.0
    var delay : Double = 0
    var start_pos : SIMD3<Float> = SIMD3()
    var direction : SIMD3<Float> = SIMD3()
    
    var calledOnStart: Bool = false
    var onStart: () -> Void = {} // option callback to trigger when started
    
    required init() {}
}

class MovieComponent : Component {
    var entity : Entity = Entity();
    var progress : Double = 0
    var animation_queue : [Animation] = []

    func handleCurrentAnimation() {
        guard var current_animation = self.find_current_animation()
        else { return }
        
        if (current_animation.start_time == 0) {
            current_animation.start_time = self.progress
            current_animation.start_pos = self.entity.position(relativeTo: nil)
        }
        // nothing to do yet, still in delay phase
        let time_for_animation = current_animation.start_time + current_animation.delay
        print(progress, time_for_animation)
        if (self.progress < time_for_animation) {
            return
        }

        if (!current_animation.calledOnStart
            && self.progress > current_animation.start_time + current_animation.delay) {
            current_animation.onStart()
            current_animation.calledOnStart = true;
        }
        
        let pct = Float(
            min(
                max(
                    (self.progress - current_animation.start_time - current_animation.delay) / current_animation.duration,
                    0.0
                ),
                1.0
            )
        );
        
        let new_pos = current_animation.start_pos +
            SIMD3<Float>(pct, pct, pct) * current_animation.direction;
        
        self.entity.setPosition(new_pos, relativeTo: nil)
    }
    
    func find_current_animation() -> Animation? {
        var timecode = 0.0
        for anim in self.animation_queue {
            let total_anim_time = anim.duration + anim.delay
            if (self.progress < timecode + total_anim_time) {
                return anim;
            }
            timecode += anim.duration + anim.delay
        }
        return nil
    }
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
           mc.progress += context.deltaTime
           mc.handleCurrentAnimation()
           entity.components.set(mc) // update progress
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
        let moveUp = Animation.init()
        moveUp.duration = 10
        moveUp.delay = 5
        moveUp.onStart = self.playMovie
        moveUp.direction = SIMD3<Float>(0, 2, 0)
        
        let moveBack = Animation.init()
        moveBack.duration = 3
        moveBack.delay = 0
        moveBack.direction = SIMD3<Float>(0, -0.2, 10)
        
        var mc = MovieComponent()
        mc.entity = screen
        mc.animation_queue = [
            moveUp, moveBack
        ]
        screen.components.set(mc)
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
