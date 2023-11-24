import SwiftUI
import UIKit

enum VideoFormat {
    case BGRA_32
    case Default
}

class DepthConfiguration {
    var useEstimation: Bool
    var videoFormat: VideoFormat

    init(useEstimation: Bool = true) {
        self.useEstimation = useEstimation
        if useEstimation {
            self.videoFormat = VideoFormat.BGRA_32
        } else {
            self.videoFormat = VideoFormat.Default  
        }
    }
}
