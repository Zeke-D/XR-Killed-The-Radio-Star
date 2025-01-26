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
import Foundation
import SystemConfiguration.CaptiveNetwork

let debugOSC = false
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


func getIPAddress() -> String? {
    var address: String?
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    
    func printAllInterfaces() {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var pointer = ifaddr
            while pointer != nil {
                if let name = String(validatingUTF8: pointer!.pointee.ifa_name) {
                    print("Interface: \(name)")
                }
                pointer = pointer!.pointee.ifa_next
            }
            freeifaddrs(ifaddr)
        }
    }
    printAllInterfaces()

    if getifaddrs(&ifaddr) == 0 {
        var pointer = ifaddr
        while pointer != nil {
            let interface = pointer!.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                if let name = String(validatingUTF8: interface.ifa_name) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    address = String(cString: hostname)
                    print(address)
                }
            }
            pointer = interface.ifa_next
        }
        freeifaddrs(ifaddr)
    }
    return address
}


class XRKOscServer {
    let myID: UUID
    let oscServer = OSCServer(port:8000)
    let root: Entity
    init(myID: UUID, root: Entity){
        if let ip = getIPAddress() {
            print("IP Address: \(ip)")
        } else {
            print("Unable to get IP address")
        }
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
