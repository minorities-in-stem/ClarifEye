import SwiftUI
import UIKit
import ARKit

class ClassificationData {
    var label: String
    var confidence: Float
    var distance: Float
    var boundingBox: CGRect

    init(label: String,
         confidence: Float,
         distance: Float,
         boundingBox: CGRect) {
        self.label = label
        self.confidence = confidence
        self.distance = distance
        self.boundingBox = boundingBox
    }
}

class ImageClassification {
    var classifications: [ClassificationData]
    var transform: simd_float4x4
    
    init(classifications: [ClassificationData], transform: simd_float4x4) {
        self.classifications = classifications
        self.transform = transform
    }
}
