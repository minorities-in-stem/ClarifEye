import Foundation

class Settings: ObservableObject {
    var cameraDepthManager: CameraDepthManager?
    
    var maxDepth = Float(15)
    var minDepth = Float(0.0)
    var depthFilterOpacity = Float(0.0)
    var useDepthEstimation = false {
        didSet {
            cameraDepthManager?.useDepthEstimation = useDepthEstimation
        }
    }
    var isFilteringDepth = false {
        didSet {
            cameraDepthManager?.isFilteringDepth = isFilteringDepth
        }
    }
}
