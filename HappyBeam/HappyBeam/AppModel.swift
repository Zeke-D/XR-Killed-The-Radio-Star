import SwiftUI
import RealityKit
import AVFoundation
import AVKit
import AudioKit
import OSCKit
import Foundation
import ARKit
import HappyBeamAssets

extension HandAnchor.Chirality {
    @MainActor
    func snapAudioResource() -> AudioFileResource {
        switch self {
        case .left:
            AppModel.shinySnap
        case .right:
            AppModel.shinySnapRight
        }
    }
}

class Animation {
    var start_time: Double = 0
    var duration : Double = 1.0
    var delay : Double = 0
    var start_pos : SIMD3<Float> = SIMD3()
    var direction : SIMD3<Float> = SIMD3()
    
    var calledOnStart: Bool = false
    var onStart: () -> Void = {} // option callback to trigger when started
    
    required init() {}
    required init(duration: Double, delay: Double, direction: SIMD3<Float>) {
        self.duration = duration
        self.delay = delay
        self.direction = direction
    }
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
    
    var leftIndex: AnchorEntity = AnchorEntity()
    var rightIndex: AnchorEntity = AnchorEntity()
    var floorAnchor: AnchorEntity = AnchorEntity()
    var headAnchor: AnchorEntity = AnchorEntity()

    static var blue_metal = SimpleMaterial(color: .blue, roughness: 0, isMetallic: true);
    static var text_on_mat = SimpleMaterial(color: .lightGray, roughness: 3, isMetallic: false);
    static var text_off_mat = SimpleMaterial(color: .black, roughness: 3, isMetallic: false);
    
    let myID = UUID()
    
    let root = Entity()
    
    static let shinySnap = try! AudioFileResource.load(named: "shiny-snap")
    static let shinySnapRight = try! AudioFileResource.load(named: "SNAPWETRIGHT")
    static let eltlongjlohng_model = (try! ModelEntity.load(named: "xrk/eltlongjlohng", in: happyBeamAssetsBundle)).children[0]
    static var mainTrackAudio = try! AudioFileResource.load(named: "Rocketman", configuration: .init(shouldLoop: true) )

    static let audioTracks : [AudioFileResource] = [
        try! AudioFileResource.load(named: "2MINUTE_ACOUSTICGUITAR", configuration: .init(shouldLoop: true) ),
        try! AudioFileResource.load(named: "2MINUTE_BASS", configuration: .init(shouldLoop: true) ),
        try! AudioFileResource.load(named: "2MINUTE_DRUMS", configuration: .init(shouldLoop: true) ),
        try! AudioFileResource.load(named: "2MINUTE_PIANO", configuration: .init(shouldLoop: true) ),
        try! AudioFileResource.load(named: "2MINUTE_VOX", configuration: .init(shouldLoop: true) ),
    ]
    
    // text entities
    var welcomeText = Entity()
    var spatialVidText = Entity()
    var spatialAudText = Entity()
    var videoText = Entity()
    var audioText = Entity()
    var gestureText = Entity()
    
    var snapParticle = Entity()
    
    private var oscBroadcastTask: Task<Void, Never>? // Add this property

    var spatialStems: [AudioPlaybackController] = []
    
    static var videoAssets = [
        AVPlayer(playerItem:
            AVPlayerItem(
                asset: AVURLAsset(
                    url: Bundle.main.url(forResource: "Cinematic_H264", withExtension: "mp4")!
                )
            )
        ),
        AVPlayer(playerItem: AVPlayerItem(asset: AVURLAsset(url: Bundle.main.url(forResource: "concert", withExtension: "MOV")!)))
    ]
    
    static var videoAsssetQueue = AVQueuePlayer(items: [
        AVPlayerItem(
            asset: AVURLAsset(
                url: Bundle.main.url(forResource: "Cinematic_H264", withExtension: "mp4")!
            )
        ),
        AVPlayerItem(
            asset: AVURLAsset(
                url: Bundle.main.url(forResource: "concert", withExtension: "MOV")!
            )
        )
    ])
    
    
    static var travelSpatialItem: AVPlayerItem = AVPlayerItem(
        asset: AVURLAsset(url: Bundle.main.url(forResource: "TRAVELSPATIAL", withExtension: "mov")!))
    static var loopingReelPlayer = AVQueuePlayer(
        items: [ travelSpatialItem ]
        
    )
    static var spatialVideoReel =
    AVPlayerLooper(player: loopingReelPlayer, templateItem: travelSpatialItem)
    
    
    init() {
        Self.text_on_mat.faceCulling = .none
        Self.text_off_mat.faceCulling = .none
        
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
    
    static let asteroid_model = (try! ModelEntity.load(named: "Asteroid_1a", in: happyBeamAssetsBundle)).children[0]
    
    enum PlayingState {
        case notStarted
        case inTheater
        case musicStart
        case flatVideo
        case spatialVideo
        case fullOuterSpace
        case collaborative
    }
    
    // initial playingstate
    var playingState = PlayingState.notStarted
    //    var playingState = PlayingState.spatialVideo
    
    
    var movieScene = Entity()
    var rocketScene = Entity()
    var mainTrackEntity = Entity()
    var asteroid_container = Entity()
    
    var grabbedEntity: Entity? = nil
    
    func makeSnapEntity(snapType: HandAnchor.Chirality) -> Entity {
        let resource = snapType.snapAudioResource()
        var snapEntity = Entity()
        snapEntity.orientation = .init(angle: .pi, axis: [0, 1, 0])
        snapEntity.spatialAudio = SpatialAudioComponent(gain: -3.0)
        snapEntity.playAudio(resource)
        return snapEntity
    }
    
    func handleSnap(value: MySnap.Value) -> Void {
        switch self.playingState {
        case .notStarted:
            self.drawMovieScene()
            self.playingState = .inTheater
            let snapEntity = makeSnapEntity(snapType: value.chirality)
            snapEntity.setPosition(value.position, relativeTo: nil)
            spaceOrigin.addChild(snapEntity)
        case .inTheater:
            self.dimLightsAndPlayMusic()
            self.playingState = .musicStart
            let snapEntity = makeSnapEntity(snapType: value.chirality)
            snapEntity.setPosition(value.position, relativeTo: nil)
            spaceOrigin.addChild(snapEntity)
        case .musicStart, .flatVideo, .spatialVideo:
            self.gestureText.modelComponent?.materials = [ Self.text_on_mat ]
            let snapEntity = makeSnapEntity(snapType: value.chirality)
            snapEntity.setPosition(value.position, relativeTo: nil)
            spaceOrigin.addChild(snapEntity)
            break
        case .fullOuterSpace:
            self.gestureText.modelComponent?.materials = [ Self.text_on_mat ]
            let snapEntity = makeSnapEntity(snapType: value.chirality)
            snapEntity.setPosition(value.position, relativeTo: nil)
            spaceOrigin.addChild(snapEntity)
            let newMesh = MeshResource.generateSphere(radius: 0.1)
            let newMat = SimpleMaterial(color: .blue, roughness: 0, isMetallic: true);
            let newSphere = ModelEntity(mesh: newMesh, materials: [newMat])
            spaceOrigin.addChild(newSphere)
            newSphere.setPosition(value.position, relativeTo: nil)
            let sphereSequence = AnimationSequenceComponent()
            sphereSequence.entity = newSphere
            let fly_up = Animation(duration: 10, delay: 0, direction: SIMD3(0, 10, 0))
            let die = Animation(duration: 10, delay: 0, direction: SIMD3())
            die.onStart = { newSphere.removeFromParent() }
            sphereSequence.animation_queue = [ fly_up, die ]
            newSphere.components.set(sphereSequence)
            
            var particles = self.snapParticle.clone(recursive: false)
            spaceOrigin.addChild(particles)
            particles.setPosition(value.position, relativeTo: nil)
            break
        case .collaborative:
            print("Done!")
        default: break
        }
    }
    
    var musicStartTime: TimeInterval = 0
    func dimLightsAndPlayMusic() {
        musicStartTime = Date().timeIntervalSinceReferenceDate
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
        
        self.mainTrackEntity.orientation = .init(angle: .pi, axis: [0, 1, 0])
        self.mainTrackEntity.spatialAudio = SpatialAudioComponent(gain: 25.0)
        self.mainTrackEntity.spatialAudio?.distanceAttenuation = .rolloff(factor: 0.4)
        
        var screen = self.movieScene.findEntity(named: "Screen")!
        screen.addChild(self.mainTrackEntity)
        self.spatialStems.append(self.mainTrackEntity.playAudio(Self.mainTrackAudio))
        
        // play movie after delay
        let moveUp = Animation.init()
        moveUp.duration = 10
        moveUp.delay = 5
        moveUp.onStart = {
            self.playMovie(video: Self.videoAsssetQueue)
            self.videoText.modelComponent?.materials = [ Self.text_on_mat ]
            self.playingState = .flatVideo
            self.spatialVidText.isEnabled = false
        }
        moveUp.direction = SIMD3<Float>(0, 3.3, 0)
        
        let moveBack = Animation.init()
        moveBack.duration = 10
        moveBack.delay = 0
        moveBack.direction = SIMD3<Float>(0, 0, 3.5)
        
        let moveBackAndPlaySpatial = Animation.init()
        moveBackAndPlaySpatial.duration = 10
        moveBackAndPlaySpatial.delay = 0
        moveBackAndPlaySpatial.direction = SIMD3<Float>(0, 0, 4)
        moveBackAndPlaySpatial.onStart = {
//            self.playMovie(video: Self.videoAssets[1])
            self.playingState = .spatialVideo
            self.spatialVidText.modelComponent?.materials = [ Self.text_on_mat ]
            self.spatialVidText.isEnabled = true
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
        
        let moveText = Animation(duration: 5, delay: 2, direction: SIMD3(0, 0, -0.2))
        let welcomeDie = Animation(duration: 1, delay: 0, direction: SIMD3())
        welcomeDie.onStart = { self.welcomeText.removeFromParent() }
        var textMoveSequence = AnimationSequenceComponent()
        textMoveSequence.entity = self.welcomeText
        textMoveSequence.animation_queue = [ moveText, welcomeDie ]
        self.welcomeText.components.set(textMoveSequence)
        
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
            self.spatialAudText.modelComponent?.materials = [ Self.text_on_mat ]
            self.audioText.modelComponent?.materials      = [ Self.text_on_mat ]
        }
        
        var setupSpatialVideoPlayers = Animation()
        setupSpatialVideoPlayers.onStart = {
            var spatialVideoWall = Entity()
            for offset in [
                SIMD3<Float>(60, 0, 0),
                SIMD3<Float>(0, 60, 0),
                SIMD3<Float>(0, 0, 60),
                SIMD3<Float>(-60, 0, 0),
                SIMD3<Float>(0, -60, 0),
                SIMD3<Float>(0, 0, -60),
            ] {
                spaceOrigin.addChild(spatialVideoWall)
                spatialVideoWall.setPosition(SIMD3(), relativeTo: self.headAnchor)
                var new_screen = screen.clone(recursive: true)
                new_screen.components.remove(AnimationSequenceComponent.self)
                spatialVideoWall.addChild(new_screen)
                new_screen.setPosition(self.headAnchor.position(relativeTo: nil) + offset, relativeTo: nil)
                new_screen.look(at: self.headAnchor.position, from: new_screen.position, relativeTo: new_screen.parent)
                new_screen.setScale(SIMD3(16,16, 1), relativeTo: new_screen)
//                Self.videoAssets[1].seek(to: .zero)
                
//                var replaySequence = AnimationSequenceComponent()
//                replaySequence.entity = new_screen
//                var replay = Animation(duration: 1, delay: 5, direction: SIMD3())
//                replay.onStart = {
//                    Self.loopingReelPlayer.seek(to: .zero)
//                    // reset sequence
//                    replaySequence.progress = 0
//                    // reset animation
//                    replay.start_time = 0
//                    replay.calledOnStart = false
//                    replaySequence.animation_queue = [ replay ]
//                }
//                replaySequence.animation_queue = [ replay ]
//                new_screen.components.set(replaySequence)
//
                Task {
                    while true {
                        try? await Task.sleep(for: .seconds(98))
                        await Self.loopingReelPlayer.seek(to: .zero)
                    }
                }
                self.playMovie(screen_entity: new_screen, player: Self.loopingReelPlayer)
//                Self.videoAsssetQueue.play()
            }
        }
        
        var rocketMotionSequence = AnimationSequenceComponent()
        rocketMotionSequence.entity = rocket
        rocketMotionSequence.animation_queue = [
            movePastPlayer,
            setupSpatialVideoPlayers
        ]
        rocket.components.set(rocketMotionSequence)
    }
    
    func drawMovieScene() {
        
        self.headAnchor = AnchorEntity(.head)
        self.headAnchor.anchoring.trackingMode = .once
        
        self.floorAnchor = AnchorEntity(.plane(.horizontal, classification: .floor, minimumBounds: [0.5, 0.5]))
        self.floorAnchor.anchoring.trackingMode = .once
        
        self.leftIndex = AnchorEntity(.hand(.left, location: .indexFingerTip))
        self.leftIndex.anchoring.trackingMode = .continuous
        
        self.rightIndex = AnchorEntity(.hand(.right, location: .indexFingerTip))
        self.rightIndex.anchoring.trackingMode = .continuous
        
        spaceOrigin.addChild(headAnchor)
        spaceOrigin.addChild(floorAnchor)
        spaceOrigin.addChild(leftIndex)
        spaceOrigin.addChild(rightIndex)
        spaceOrigin.addChild(movieScene)
        let headPos = headAnchor.position(relativeTo:nil)
        let floorPos = floorAnchor.position(relativeTo: nil)
        self.movieScene.setPosition( SIMD3(headPos.x, floorPos.y, headPos.z - 2.5), relativeTo: nil)
        
        self.welcomeText = self.movieScene.findEntity(named: "Welcome")!
        self.gestureText = self.movieScene.findEntity(named: "CustomGestures")!
        self.spatialVidText = self.movieScene.findEntity(named: "Spatial")!
        self.spatialAudText = self.movieScene.findEntity(named: "Spatial_2")!
        self.videoText = self.movieScene.findEntity(named: "Video")!
        self.audioText = self.movieScene.findEntity(named: "Audio")!
        self.welcomeText.modelComponent?.materials = [ Self.text_on_mat ]
        self.gestureText.modelComponent?.materials = [ Self.text_off_mat ]
        self.spatialVidText.modelComponent?.materials = [ Self.text_off_mat ]
        self.spatialAudText.modelComponent?.materials = [ Self.text_off_mat ]
        self.videoText.modelComponent?.materials = [ Self.text_off_mat ]
        self.audioText.modelComponent?.materials = [ Self.text_off_mat ]
        
        spaceOrigin.addChild(rocketScene)
        
        // Setup asteroids
        Task {
            // Audio track names in order
            
            for i in 0..<20 {
                let asteroid = Self.asteroid_model.clone(recursive: true)
                
                // Randomize the asteroid properties
                var radius = Float.random(in: 3...18)
                let speed = Float.random(in: 0.1...0.4)
                let rotation = Float.random(in: 0.1...0.5)
                let startAngle = Float(i) * (2 * .pi / 10)
                let height = Float.random(in: -2...4)
                
                // Scale down the asteroid
                asteroid.scale = SIMD3<Float>(repeating: 0.3)
                
                //                mainTrackEntity.components[SpatialAudioComponent.self]?.gain = 0.0
                
                // Add spatial audio for first 4 asteroids using OrbController pattern
                if i < 4 {
                    let audioSource = Entity()
                    audioSource.spatialAudio = SpatialAudioComponent(gain: -1.5)
                    asteroid.addChild(audioSource)
                    radius = 2;
                    
                    let audioResource = Self.audioTracks[i % 5]
                    let controller = audioSource.playAudio(audioResource)
                    
                    spatialStems.append(controller)
                } else {
                }
                
                
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
    
    func playMovie(video: AVPlayer) {
        let movieScreen = self.movieScene.findEntity(named: "Screen")!
        playMovie(screen_entity: movieScreen, player: video)
    }
    
    func playMovie(screen_entity: Entity, player: AVPlayer) {
        player.isMuted = true; // no sound of concert
        let material = VideoMaterial(avPlayer: player)
        screen_entity.modelComponent!.materials = [material]
        player.play()
    }
    
    func createAsteroidField() {
        // Register the asteroid system
        AsteroidSystem.registerSystem()
        
        
        
        // Create the eltlongjlohng entity
        let eltlongjlohng = Self.eltlongjlohng_model.clone(recursive: true)
        
        eltlongjlohng.components.set(EltonComponent())
        
        // Scale and position it
        eltlongjlohng.scale = SIMD3<Float>(repeating: 4)
        eltlongjlohng.position = SIMD3<Float>(0, 2, -10) // Adjust position as needed
        
        
        
        // Add asteroid component for orbital motion
        let component = AsteroidComponent(
            radius: 40.0,
            speed: 0.2,
            rotation: 0.3,
            startAngle: 0,
            height: 2.0
        )
        eltlongjlohng.components.set(component)
        //        eltlongjlohng.addChild(self.mainTrackEntity)
        
        // silence single main track
        Task {
            try? await Task.sleep(for: .seconds(8))
            await MainActor.run(body: {
                mainTrackEntity.components[SpatialAudioComponent.self]?.gain = -100.0
            })
        }
        
        let audioSource = Entity()
        audioSource.spatialAudio = SpatialAudioComponent()
        eltlongjlohng.addChild(audioSource)
        
        let audioResource = Self.audioTracks[4]
        let controller = audioSource.playAudio(audioResource)
        
        spatialStems.append(controller)
        
        // skip main track
        for i in 1..<self.spatialStems.count {
            // sync the spatial audio with the main audio track
            self.spatialStems[i].seek(to: .seconds(Date().timeIntervalSinceReferenceDate - musicStartTime))
        }
        audioSource.spatialAudio?.distanceAttenuation = .rolloff(factor: 0.1)
        
        
        
        // Add to container
        asteroid_container.addChild(eltlongjlohng)
        
        // Create asteroids
        spaceOrigin.addChild(self.asteroid_container)
    }
}
