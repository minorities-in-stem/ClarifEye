import SwiftUI
import UIKit
import ARKit

struct ClassificationData {
    var label: String
    var confidence: Float
    var distance: Float?
    var boundingBox: CGRect
}

struct ImageClassification {
    var imageSize: CGSize
    var classifications: Dictionary<String, ClassificationData>
    var transform: simd_float4x4
}

struct ScoredClassification {
    var classification: ClassificationData
    var score: Float
}
