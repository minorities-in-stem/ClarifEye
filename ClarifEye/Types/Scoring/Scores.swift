import Foundation

// TODO: move to a different file
func CalculateScore(label: ObstacleLabel, depth: Float, speed: Float) -> Float {
    var a: Float = 0.5
    var b: Float = 1.8
    var c: Float = 1
    
    var obstacle = label.obstacleClass
    
    var s = obstacle.hazardScore
    var g = DepthSeverity.severity(forDepth: depth).rawValue
    var f = SpeedSeverity.severity(forSpeed: speed).rawValue
    
    var sev1 = a*s
    var sev2 = b*g
    var sev3 = c*f
    
    return sev1 + sev2 + sev3
}

enum Obstacle: String {
    case VEHICLE
    case CYCLIST
    case STAIRS
    case CONSTRUCTION
    case WALL
    case FENCE
    case BARRIER
    case POLE
    case TREE
    case PERSON
    case NONE // Use for obstacles we don't really case about for now
    
    var hazardScore: Float {
        switch self {
            case .VEHICLE: return 4
            case .CYCLIST: return 3
            case .STAIRS: return 3
            case .CONSTRUCTION: return 3
            case .WALL: return 2
            case .FENCE: return 2
            case .BARRIER: return 2
            case .POLE: return 2
            case .TREE: return 2
            case .PERSON: return 1
            case .NONE: return 0
        }
    }
}

struct DepthSeverity {
    enum SeverityScore: Float {
        case UNKNOWN = -1
        case NONE = 0
        case VERY_LOW = 1
        case LOW = 2
        case MODERATE = 3
        case HIGH = 4
        case VERY_HIGH = 5
    }
    
    static func severity(forDepth depth: Float) -> SeverityScore {
        switch depth {
        case ..<1.0:
            return .VERY_HIGH
        case 1.0..<2.0:
            return .HIGH
        case 2.0..<3.0:
            return .MODERATE
        case 3.0..<3.5:
            return .LOW
        case 3.5..<4.0:
            return .VERY_LOW
        case 4.0...:
            return .NONE
        default:
            return .UNKNOWN
        }
    }
}

struct SpeedSeverity {
    enum SeverityScore: Float {
        case UNKNOWN = -1
        case NONE = 0
        case VERY_LOW = 1
        case LOW = 2
        case MODERATE = 3
        case HIGH = 4
        case VERY_HIGH = 5
    }
    
    static func severity(forSpeed speed: Float) -> SeverityScore {
        switch speed {
        case ..<0.5:
            return .NONE
        case 0.5..<1.0:
            return .VERY_LOW
        case 1.0..<2.0:
            return .LOW
        case 2.0..<4.0:
            return .MODERATE
        case 4.0..<5.0:
            return .HIGH
        case 5.0...:
            return .VERY_HIGH
        default:
            return .UNKNOWN
        }
    }
}
