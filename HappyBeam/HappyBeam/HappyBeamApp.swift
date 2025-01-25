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
        WindowGroup {
            VStack{
                PlayerView()
                ContentView()
                    .environment(appModel)
            }
        }
        
        ImmersiveSpace(id: "mainView") {
            MainView().environment(appModel)
        }
        .immersionStyle(selection: $immersionState, in: .mixed)
    }
}

@MainActor
enum HeartGestureModelContainer {
    private(set) static var heartGestureModel = HeartGestureModel()
}
