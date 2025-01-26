//
//  Multiplayer.swift
//  HappyBeam
//
//  Created by Kevin King on 1/25/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import RealityKit
import AVFoundation
import OSCKit

let debugOSC = true
let soundOnRX = false

struct OneShotComponent: Component {
    let controller: AudioPlaybackController
    var remainingLifetime: Double
}

class OneShotSystem : System {
    private static let query = EntityQuery(where: .has(OneShotComponent.self))
    
    required init(scene: RealityKit.Scene) { }
    
    func update(context: SceneUpdateContext) {
        for entity in context.entities(
            matching: Self.query,
            updatingSystemWhen: .rendering
        ) {
            entity.components[OneShotComponent.self]?.remainingLifetime -= context.deltaTime
            if entity.components[OneShotComponent.self]?.remainingLifetime ?? 0 <= 0 {
                entity.removeFromParent()
            }
        }
    }
}

class XRKOscServer {
    let myID: UUID
    let oscServer = OSCServer(port:8000)
    let root: Entity
    init(myID: UUID, root: Entity){
        self.root = root
        try! oscServer.start()
        self.myID = myID
        oscServer.setHandler(
            {message, timeTag in
                if debugOSC {
                    print("Received \(message) \(message.addressPattern)")
                }
                if message.addressPattern.stringValue.starts(with: "/\(myID)") {
                    if debugOSC {
                        print("from me, ignoring...")
                    }
                    return
                }
                
                if soundOnRX {
                    Task {
                        await MainActor.run {
                            // other device!
                            let audioOneshot = Entity()
                            root.addChild(audioOneshot)
                            let controller = audioOneshot.playAudio(AppModel.shinySnap)
                            audioOneshot.components.set(OneShotComponent(controller: controller, remainingLifetime: 10))
                        }
                    }
                }
            }
        )
    }
}
