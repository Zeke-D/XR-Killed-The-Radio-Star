//
//  SnapGesture.swift
//  HappyBeam
//
//  Created by Zeke D'Ascoli on 1/24/25.
//  Copyright © 2025 Apple. All rights reserved.
//


//
//  SnapGesture.swift
//  HandGesture
//
//  Created by John Haney on 12/2/24.
//

import Foundation
import ARUnderstanding
import ARKit
import HandGesture
import RealityKit
import Spatial

public class MySnap: HandGesture {
    public struct Value : Equatable, Sendable {
        public let pose: SnapPose
        public let chirality: HandAnchor.Chirality
        public let position: SIMD3<Float>
    }
    
    public let id: UUID = UUID()
    var hand: HandAnchor.Chirality
    var maximumSnapTime: TimeInterval = 0.5
    var lastPreSnap: Date? = nil
    
    public enum SnapPose: Equatable, Sendable {
        case noSnap
        case preSnap
        case postSnap
    }
    
    public init(hand: HandAnchor.Chirality) {
        self.hand = hand
    }
    
    public func update(with handUpdates: HandTrackingModel.HandsUpdates) -> Value? {
        switch hand {
        case .right:
            if let rightHand = handUpdates.right,
               let snapPose = rightHand.snapPose() {
                let value: Value?
                let position = rightHand.position(joint: .middleFingerTip) ?? SIMD3<Float>()
                switch snapPose {
                case .noSnap:
                    value = .init(pose: .noSnap,
                                  chirality: hand,
                                  position: position )
                case .preSnap:
                    lastPreSnap = Date()
                    value = .init(pose: .preSnap, chirality: hand, position: position)
                case .postSnap:
                    if let preSnap = lastPreSnap,
                       -preSnap.timeIntervalSinceNow <= maximumSnapTime {
                        lastPreSnap = nil
                        value = .init(pose: .postSnap, chirality: hand, position: position)
                    } else {
                        value = nil
                    }
                }
                return value
            }
        case .left:
            if let leftHand = handUpdates.left,
               let snapPose = leftHand.snapPose() {
                let value: Value?
                let position = leftHand.position(joint: .middleFingerTip) ?? SIMD3<Float>()

                switch snapPose {
                case .noSnap:
                    value = .init(pose: .noSnap, chirality: hand, position: position)
                case .preSnap:
                    lastPreSnap = Date()
                    value = .init(pose: .preSnap, chirality: hand, position: position)
                case .postSnap:
                    if let preSnap = lastPreSnap,
                       -preSnap.timeIntervalSinceNow <= maximumSnapTime {
                        lastPreSnap = nil
                        value = .init(pose: .postSnap, chirality: hand, position: position)
                    } else {
                        value = nil
                    }
                }
                return value
            }
        }
        return .init(pose: .noSnap, chirality: hand, position: SIMD3<Float>())
    }
}

extension HandAnchorRepresentable {
    func snapPose() -> SnapGesture.SnapPose? {
        guard let distanceOne = distanceBetween(.thumbTip, .thumbIntermediateTip),
              let distanceTwo = distanceBetween(.middleFingerTip, .middleFingerIntermediateTip)
        else { return nil }
        if let distance = distanceBetween(.thumbTip, .middleFingerTip),
           distance < distanceTwo {
            return .preSnap
        }
        if let distance = distanceBetween(.thumbIntermediateTip, .middleFingerIntermediateTip),
           distance < distanceTwo {
            return .preSnap
        }
        if let distance = distanceBetween(.middleFingerTip, .indexFingerMetacarpal),
           distance < distanceOne+distanceTwo {
            return .postSnap
        }
        if let distance = distanceBetween(.middleFingerTip, .thumbKnuckle),
           distance/2 < max(distanceOne,distanceTwo) {
            return .postSnap
        }
        return nil
    }
}
