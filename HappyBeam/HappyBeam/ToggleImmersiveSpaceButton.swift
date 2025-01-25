//
//  ToggleImmersiveSpaceButton.swift
//  HappyBeam
//
//  Created by Zeke D'Ascoli on 1/24/25.
//  Copyright © 2025 Apple. All rights reserved.
//


//
//  ToggleImmersiveSpaceButton.swift
//  HandGestureApp
//
//  Created by John Haney on 12/8/24.
//

import SwiftUI

struct ToggleImmersiveSpaceButton: View {

    @Environment(AppModel.self) private var appModel

    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            Task { @MainActor in
                await self.toggleState()
            }
        } label: {
            Text(appModel.immersiveSpaceState == .open ? "Hide Immersive Space" : "Show Immersive Space")
        }
        .disabled(appModel.immersiveSpaceState == .inTransition)
        .animation(.none, value: 0)
        .fontWeight(.semibold)
    }
    
    func toggleState() async {
        switch appModel.immersiveSpaceState {
            case .open:
                appModel.immersiveSpaceState = .inTransition
                await dismissImmersiveSpace()
                // Don't set immersiveSpaceState to .closed because there
                // are multiple paths to ImmersiveView.onDisappear().
                // Only set .closed in ImmersiveView.onDisappear().

            case .closed:
                appModel.immersiveSpaceState = .inTransition
                switch await openImmersiveSpace(id: appModel.immersiveSpaceID) {
                    case .opened:
                        dismiss()
                        // Don't set immersiveSpaceState to .open because there
                        // may be multiple paths to ImmersiveView.onAppear().
                        // Only set .open in ImmersiveView.onAppear().
                        break

                    case .userCancelled, .error:
                        // On error, we need to mark the immersive space
                        // as closed because it failed to open.
                        fallthrough
                    @unknown default:
                        // On unknown response, assume space did not open.
                        appModel.immersiveSpaceState = .closed
                }

            case .inTransition:
                // This case should not ever happen because button is disabled for this case.
                break
        }

    }
}
