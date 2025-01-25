import SwiftUI
import RealityKit
import AVFoundation
import AVKit

struct PlayerView: UIViewControllerRepresentable {
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        //
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        // Wrap AVPlayerViewController in a plain UIViewController to manage its view lifecycle more directly
        let containerViewController = UIViewController()
        let playerViewController = AVPlayerViewController()
        let url = Bundle.main.url(forResource: "SpatialTest", withExtension: "MP4")!
        print(url)
        let player = AVPlayer(url:url)
        // Configure the player
        playerViewController.player = player
        playerViewController.showsPlaybackControls = false
        // Ensure the player view controller's view fits the container view
        playerViewController.view.frame = containerViewController.view.bounds
        playerViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // Add the player view controller as a child to the container view
        containerViewController.addChild(playerViewController)
        containerViewController.view.addSubview(playerViewController.view)
        playerViewController.didMove(toParent: containerViewController)
        player.play()
        return containerViewController
    }
}
