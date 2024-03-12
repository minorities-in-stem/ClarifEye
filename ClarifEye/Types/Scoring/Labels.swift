import Foundation

func cleanLabel(_ label: String) -> String {
    return label.replacingOccurrences(of: "_", with: " ").capitalized(with: .none)
}

enum ObstacleLabel: String {
    case PERSON = "person"
    case BICYCLE = "bicycle"
    case CAR = "car"
    case MOTORBIKE = "motorbike"
    case BUS = "bus"
    case TRAIN = "train"
    case TRUCK = "truck"
    case BOAT = "boat"
    case TRAFFIC_LIGHT = "traffic_light"
    case BICYCLER = "bicycler"
    case BRAILLE_BLOCK = "braille_block"
    case GUARDRAIL = "guardrail"
    case WHITE_LINE = "white_line"
    case CROSSWALK = "crosswalk"
    case SIGNAL_BUTTON = "signal_button"
    case SIGNAL_RED = "signal_red"
    case SIGNAL_BLUE = "signal_blue"
    case STAIRS = "stairs"
    case HANDRAIL = "handrail"
    case STEPS = "steps"
    case FAREGATES = "faregates"
    case TRAIN_TICKET_MACHINE = "train_ticket_machine"
    case SHRUBS = "shrubs"
    case TREE = "tree"
    case VENDING_MACHINE = "vending_machine"
    case BATHROOM = "bathroom"
    case DOOR = "door"
    case ELEVATOR = "elevator"
    case ESCALATOR = "escalator"
    case BOLLARD = "bollard"
    case BUS_STOP_SIGN = "bus_stop_sign"
    case POLE = "pole"
    case MONUMENT = "monument"
    case FENCE = "fence"
    case WALL = "wall"
    case SIGNBOARD = "signboard"
    case FLAG = "flag"
    case POSTBOX = "postbox"
    case SAFETY_CONE = "safety-cone"
    case DOG = "dog"
    case FIRE_HYDRANT = "fire_hydrant"
    case UNKNOWN = "unknown_object"
    
    static func fromString(_ string: String) -> ObstacleLabel {
        if let enumValue = ObstacleLabel(rawValue: string) {
            return enumValue
        } else {
            return .UNKNOWN
        }
    }
    
    var obstacleClass: Obstacle {
        switch self {
            case .CAR, .TRUCK, .BUS: return .VEHICLE
            case .BICYCLE, .BICYCLER: return .CYCLIST
            case .STAIRS, .STEPS: return .STAIRS
            case .SAFETY_CONE: return .CONSTRUCTION
            case .WALL: return .WALL
            case .FENCE: return .FENCE
            case .GUARDRAIL: return .BARRIER
            case .POLE, .BOLLARD: return .POLE
            case .TREE: return .TREE
            case .PERSON: return .PERSON
            default: return .NONE
        }
    }
}
    
