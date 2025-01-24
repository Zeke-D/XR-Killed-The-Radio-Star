import SwiftUI
import RealityKit

struct SoundOrbView: View {
    // Keep the orb’s logic in an ObservableObject
    @StateObject private var controller: OrbController
    
    init(soundFile: String, x: Float, y: Float, z: Float) {
        // Initialize our OrbController here
        _controller = StateObject(wrappedValue: OrbController(
            soundFile: soundFile,
            x: x,
            y: y,
            z: z
        ))
    }
    
    var body: some View {
        RealityView { content in
            content.add(controller.orb)
        }
        .gesture(
            SimultaneousGesture(
                // Drag gesture
                DragGesture()
                    .targetedToAnyEntity()
                    .onChanged { value in
                        // Convert to local coords
                        controller.orb.position = value.convert(
                            value.location3D,
                            from: .local,
                            to: controller.orb.parent!
                        )
                    },
                
                // Tap gesture
                TapGesture()
                    .targetedToAnyEntity()
                    .onEnded { value in
                        // Check if the tapped entity is 'controller.orb' or one of its children
                        var tappedEntity: Entity? = value.entity
                        // print("Tapped entity:", tappedEntity?.name ?? "nil")
                        
                        while let current = tappedEntity {
                            if current == controller.orb {
                                // print("Toggling audio for:", current.name)
                                controller.toggleAudio()
                                break
                            }
                            tappedEntity = current.parent
                        }
                    }
            )
        )
    }
}
