import Foundation

// TODO: move to a different file
func CalculateScore(label: ObstacleLabel, depth: Float?, speed: Float) -> Float {
    let a: Float = 0.5
    let b: Float = 1.8
    let c: Float = 1
    
    let obstacle = label.obstacleClass
    
    let s = obstacle.hazardScore
    let g = depth == nil ? 0 : DepthSeverity.severity(forDepth: depth!).rawValue
    let f = SpeedSeverity.severity(forSpeed: speed).rawValue
    
    let sev1 = a*s
    let sev2 = b*g
    let sev3 = c*f
    
    return sev1 + sev2 + sev3
}

enum Obstacle: String {
    case VEHICLE = "vehicle"
    case CYCLIST = "cyclist"
    case STAIRS = "stairs"
    case CONSTRUCTION = "construction"
    case WALL = "wall"
    case FENCE = "fence"
    case BARRIER = "barrier"
    case POLE = "pole"
    case TREE = "tree"
    case PERSON = "person"
    case NONE = "none" // Use for obstacles we don't really case about for now
    
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
