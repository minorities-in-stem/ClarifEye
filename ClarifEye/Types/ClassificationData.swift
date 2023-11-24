import SwiftUI
import UIKit

class ClassificationData {
    var label: String
    var confidence: Float
    var distance: Float
    var boundingBox: CGRect

    init(label: String,
         confidence: Float,
         distance: Float, boundingBox: CGRect) {
        self.label = label
        self.confidence = confidence
        self.distance = distance
        self.boundingBox = boundingBox
    }
}
