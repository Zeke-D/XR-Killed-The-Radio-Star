/*
 See the LICENSE.txt file for this sample’s licensing information.
 
 Abstract:
 The app structure.
 */

import SwiftUI
import RealityKit

/// The structure of the Happy Beam app: a main window and a Full Space for gameplay.
@main
struct HappyBeamApp: App {
    @State private var appModel = AppModel()
    @State private var immersionState: ImmersionStyle = .mixed
    
    var body: some SwiftUI.Scene {
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            MainView().environment(appModel)
            //            SoundOrbView(soundFile: "MONOSTEM.mp3", x: 0, y: 1.5, z: -1)
            //            SoundOrbView(soundFile: "10TO3KSWEEP.wav", x: 0, y: 1.5, z: -1)
            //SoundOrbView(soundFile: "audio-2.wav", x: 0, y: 1.5, z: 1)
        }
        .immersionStyle(selection: $immersionState, in: .mixed)
    }
}

