import SwiftUI
import RealityKit
import AVFoundation
import AVKit
import AudioKit
import OSCKit

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

class AnimationSequenceComponent : Component {
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


class AnimationSystem : System {
    private static let query = EntityQuery(where: .has(AnimationSequenceComponent.self))

    required init(scene: RealityKit.Scene) { }

    func update(context: SceneUpdateContext) {
       for entity in context.entities(
           matching: Self.query,
           updatingSystemWhen: .rendering
       ) {
           var mc = entity.components[AnimationSequenceComponent.self]!
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
    
    let myID = UUID()
    let oscServer : XRKOscServer
    
    let root = Entity()
    
    static let shinySnap = try! AudioFileResource.load(named: "shiny-snap")

    
    init() {
        oscServer = XRKOscServer(myID: myID, root: root)
        Settings.audioFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        Settings.channelCount = 1
        Settings.sampleRate = 48000
        Settings.bufferLength = .veryShort
        
        let oscClient = OSCClient()
        oscClient.isIPv4BroadcastEnabled = true
        Task {
            while true {
                try! await Task.sleep(for: .seconds(1))
                // NOTE: message must start with a slash!!!
                let msg = OSCMessage("/\(myID)/test", values: ["string", 123])
                for i in 1..<4 {
                    try! oscClient.send(msg, to: "192.168.0.10\(i)")
                }
                if debugOSC {
                    print("sent!")
                }
            }
        }
        
    }
    
    let immersiveSpaceID = "mainView"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed
    
    static let asteroid_model = try! ModelEntity.load(named: "Asteroid_1a")

    enum PlayingState {
        case notStarted
        case inTheater
        case musicStart
        case flatVideo
        case spatialVideo
        case fullOuterSpace
        case collaborative
    }
    
    var playingState = PlayingState.notStarted
    
    var movieScene = Entity()
    var rocketScene = Entity()
    var mainTrackEntity = Entity()
    var asteroid_container = Entity()

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
        moveUp.onStart = {
            let url = Bundle.main.url(forResource: "SpatialTest", withExtension: "MP4")!
            self.playMovie(url: url)
            self.playingState = .flatVideo
        }
        moveUp.direction = SIMD3<Float>(0, 2.75, 0)
        
        let moveBack = Animation.init()
        moveBack.duration = 10
        moveBack.delay = 0
        moveBack.direction = SIMD3<Float>(0, 0, 4)
        
        let moveBackAndPlaySpatial = Animation.init()
        moveBackAndPlaySpatial.duration = 10
        moveBackAndPlaySpatial.delay = 0
        moveBackAndPlaySpatial.direction = SIMD3<Float>(0, 0, 4)
        moveBackAndPlaySpatial.onStart = {
            let url = Bundle.main.url(forResource: "concert", withExtension: "MOV")!
            self.playMovie(url: url)
            self.playingState = .spatialVideo
        }

        

        let explode = Animation.init()
        explode.duration = 10
        explode.onStart = {
            let theatre = self.movieScene.findEntity(named: "Theatre")!
            self.playingState = .fullOuterSpace
            for anim in theatre.availableAnimations {
                theatre.playAnimation(anim, startsPaused: false)
            }
            
            spaceOrigin.addChild(self.mainTrackEntity)
            
            Task {
                self.createAsteroidField()
            }
 
        }
        
        explode.direction = SIMD3<Float>(0, -3, -80)

        var screenMovieSequence = AnimationSequenceComponent()
        screenMovieSequence.entity = screen
        screenMovieSequence.animation_queue = [
            moveUp,
            moveBack,
            moveBackAndPlaySpatial,
            explode
        ]
        screen.components.set(screenMovieSequence)
        
        // Setup rocket animation
        let rocket = self.rocketScene.findEntity(named: "Rocket")!
        rocket.setPosition(SIMD3<Float>(10, 2, -20), relativeTo: nil)
        let rocketSound = try! AudioFileResource.load(named: "LOOPROCKET", configuration: .init(shouldLoop: true)
        )
        rocket.spatialAudio = SpatialAudioComponent()
        rocket.playAudio(rocketSound)

        var rocketDirection = SIMD3<Float>(-20, 0, 40)
        rocket.look(at: rocket.position + rocketDirection, from: rocket.position, relativeTo: nil)
        let movePastPlayer = Animation.init()
        movePastPlayer.duration = 20
        movePastPlayer.direction = rocketDirection
        movePastPlayer.delay = 30
        movePastPlayer.onStart = {
            // play rocket sound
        }
        
        var rocketMotionSequence = AnimationSequenceComponent()
        rocketMotionSequence.entity = rocket
        rocketMotionSequence.animation_queue = [
            movePastPlayer
        ]
        rocket.components.set(rocketMotionSequence)
        

    }
    
    func drawMovieScene() {
        spaceOrigin.addChild(movieScene)
        self.movieScene.setPosition(SIMD3(0, 0, -2.5), relativeTo: spaceOrigin)
        
        spaceOrigin.addChild(rocketScene)
        
        // Setup asteroids
        Task {
            for i in 0..<20 {
                let asteroid = Self.asteroid_model.clone(recursive: true)
                
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
                
                // Add to the scene
                asteroid_container.addChild(asteroid)
            }

        }

    }
    
    func playMovie(url: URL) {
        let movieScreen = self.movieScene.findEntity(named: "Screen")!
        let player = AVPlayer(url: url)
        player.isMuted = true; // no sound of concert
        let material = VideoMaterial(avPlayer: player)
        movieScreen.modelComponent!.materials = [material]
        player.play()
    }
    
    func createAsteroidField() {
        
        // Register the asteroid system
        AsteroidSystem.registerSystem()
        
        // Create 10 asteroids
        spaceOrigin.addChild(self.asteroid_container)
    }
}
