import SwiftUI
import RealityKit
import AVFoundation
import AVKit
import AudioKit

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

class MovieSequenceComponent : Component {
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
    private static let query = EntityQuery(where: .has(MovieSequenceComponent.self))

    required init(scene: RealityKit.Scene) { }

    func update(context: SceneUpdateContext) {
       for entity in context.entities(
           matching: Self.query,
           updatingSystemWhen: .rendering
       ) {
           var mc = entity.components[MovieSequenceComponent.self]!
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
    
    init() {
        Settings.audioFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        Settings.channelCount = 1
        Settings.sampleRate = 48000
        Settings.bufferLength = .veryShort
    }

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
    
    func makeSnapEntity(resource_name: String) -> Entity {
        let shinySnap = try! AudioFileResource.load(named: resource_name)
        var snapEntity = Entity()
        snapEntity.orientation = .init(angle: .pi, axis: [0, 1, 0])
        snapEntity.spatialAudio = SpatialAudioComponent()
        snapEntity.playAudio(shinySnap)
        return snapEntity
    }
    
    func handleSnap(value: MySnap.Value) -> Void {
        print("From: ", self.playingState)
        switch self.playingState {
        case .notStarted:
            self.drawMovieScene()
            self.playingState = .inTheater
            var snapEntity = makeSnapEntity(resource_name: "SNAP")
            snapEntity.setPosition(value.position, relativeTo: nil)
            spaceOrigin.addChild(snapEntity)
        case .inTheater:
            self.dimLightsAndPlayMusic()
            self.playingState = .musicStart
            var snapEntity = makeSnapEntity(resource_name: "SNAP")
            snapEntity.setPosition(value.position, relativeTo: nil)
            spaceOrigin.addChild(snapEntity)
        case .musicStart:
            self.playingState = .spatialVideo
            var snapEntity = makeSnapEntity(resource_name: "shiny-snap")
            snapEntity.setPosition(value.position, relativeTo: nil)
            spaceOrigin.addChild(snapEntity)
        case .spatialVideo:
            createAsteroidField()
            break
        case .fullOuterSpace:
            self.playingState = .collaborative
            break
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
        
        
        // play movie after delay
        let moveUp = Animation.init()
        moveUp.duration = 10
        moveUp.delay = 5
        moveUp.onStart = self.playMovie
        moveUp.direction = SIMD3<Float>(0, 2, 0)
        
        let moveBack = Animation.init()
        moveBack.duration = 10
        moveBack.delay = 0
        moveBack.direction = SIMD3<Float>(0, 0, 5)
        
        let explode = Animation.init()
        explode.duration = 0.5
        explode.onStart = {
            let theatre = self.movieScene.findEntity(named: "Theatre")!
            for anim in theatre.availableAnimations {
                theatre.playAnimation(anim, startsPaused: false)
            }
        }

        var mc = MovieSequenceComponent()
        mc.entity = screen
        mc.animation_queue = [
            moveUp, moveBack, explode
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
    
    func createAsteroidField() {
        print("🚀 Starting asteroid field creation")
        
        // Register the asteroid system
        AsteroidSystem.registerSystem()
        print("✅ Asteroid system registered")
        
        // Create 10 asteroids
        for i in 0..<20 {
            print("🌑 Attempting to create asteroid \(i+1)")
            do {
                let asteroid = try ModelEntity.load(named: "Asteroid_1a")
                print("✅ Successfully loaded Asteroid_1a model")
                
                // Randomize the asteroid properties
                let radius = Float.random(in: 3...18)
                let speed = Float.random(in: 0.1...0.4)
                let rotation = Float.random(in: 0.1...0.5)
                let startAngle = Float(i) * (2 * .pi / 10) // I think it would be fun to get crazier angles
                let height = Float.random(in: -2...4)
                
                // Scale down the asteroid
                asteroid.scale = SIMD3<Float>(repeating: 0.3)
                
                // Add the asteroid component
                let component = AsteroidComponent(
                    radius: radius,
                    speed: speed,
                    rotation: rotation,
                    startAngle: startAngle,
                    height: height
                )
                asteroid.components.set(component)
                print("✅ Added AsteroidComponent to asteroid \(i+1)")
                
                // Add to the scene
                spaceOrigin.addChild(asteroid)
                print("✅ Added asteroid \(i+1) to scene at radius: \(radius), height: \(height)")
            } catch {
                print("❌ Failed to load Asteroid_1a model: \(error)")
            }
        }
        
        print("🎯 Total entities in spaceOrigin: \(spaceOrigin.children.count)")
    }
}
