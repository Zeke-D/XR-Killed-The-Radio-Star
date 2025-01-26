//
//  AsteroidComponent.swift
//  HappyBeam
//
//  Created by Ben Crystal on 1/25/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import RealityKit

class AsteroidComponent: Component {
    var orbitRadius: Float = 5.0
    var orbitSpeed: Float = 0.3
    var rotationSpeed: Float = 1.0
    var startAngle: Float = 0.0
    var heightOffset: Float = 0.2
    
    init(radius: Float, speed: Float, rotation: Float, startAngle: Float, height: Float) {
        self.orbitRadius = radius
        self.orbitSpeed = speed
        self.rotationSpeed = rotation
        self.startAngle = startAngle
        self.heightOffset = height
    }
}

struct GrabbedComponent: Component {
    
}

class AsteroidSystem: System {
    private static let query = EntityQuery(where: .has(AsteroidComponent.self) && !.has(GrabbedComponent.self))
    
    required init(scene: RealityKit.Scene) { }
    
    func update(context: SceneUpdateContext) {
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var asteroid = entity.components[AsteroidComponent.self] else { continue }
            
            // Update orbit position
            let angle = asteroid.startAngle + (asteroid.orbitSpeed * Float(context.deltaTime))
            asteroid.startAngle = angle
            
            // Calculate new position
            let x = asteroid.orbitRadius * cos(angle)
            let z = asteroid.orbitRadius * sin(angle)
            entity.position = SIMD3<Float>(x, asteroid.heightOffset, z)
            
            // Rotate the asteroid
            entity.orientation *= simd_quatf(angle: asteroid.rotationSpeed * Float(context.deltaTime),
                                          axis: SIMD3<Float>(0, 1, 0))
            
            // Update component
            entity.components[AsteroidComponent.self] = asteroid
        }
    }
}
