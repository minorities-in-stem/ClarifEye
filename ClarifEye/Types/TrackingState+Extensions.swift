import Foundation
import ARKit

extension ARCamera.TrackingState {
    var presentationString: String {
        switch self {
            case .normal:
                return "Tracking normal"
            case .limited(.excessiveMotion):
                return "Excessive motion"
            case .limited(.insufficientFeatures):
                return "Poor Lighting"
            case .limited(.initializing):
                return "Camera initializing..."
            case .limited(.relocalizing):
                return "Recovering from interruption"
            case .notAvailable:
                return "Tracking is unavailble."
            default:
                return "Tracking is unavailable."
        }
    }
    
    var recommendation: String? {
        switch self {
        case .limited(.excessiveMotion):
            return "Try slowing down your movement, or reset the session."
        case .limited(.insufficientFeatures):
            return "Unable to detect objects. Ensure the back camera is not covered, or reset the session."
        case .limited(.relocalizing):
            return "Return to the location where you left off or try resetting the session."
        default:
            return nil
        }
    }
}
