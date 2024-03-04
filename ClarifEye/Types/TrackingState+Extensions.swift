import Foundation
import ARKit

extension ARCamera.TrackingState {
    var presentationString: String {
        switch self {
            case .normal:
                return "TRACKING NORMAL"
            case .limited(.excessiveMotion):
                return "Tracking Limited: Excessive motion"
            case .limited(.insufficientFeatures):
                return "Tracking Limited: Low detail"
            case .limited(.initializing):
                return "Initializing..."
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
            return "Try pointing at a flat surface, or reset the session."
        case .limited(.relocalizing):
            return "Return to the location where you left off or try resetting the session."
        default:
            return nil
        }
    }
}
