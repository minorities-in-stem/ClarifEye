import Foundation

func cleanLabel(_ label: String) -> String {
    return label.replacingOccurrences(of: "_", with: " ").capitalized(with: .none)
}

enum ObstacleLabel: String {
    case BATHROOM = "bathroom"
    case BENCH = "bench"
    case BICYCLE = "bicycle"
    case BICYCLER = "bicycler"
    case BOAT = "boat"
    case BOLLARD = "bollard"
    case BRAILLE_BLOCK = "braille_block"
    case BUS = "bus"
    case BUS_STOP_SIGN = "bus_stop_sign"
    case CAR = "car"
    case CHAIR = "chair"
    case CROSSWALK = "crosswalk"
    case DOG = "dog"
    case DOOR = "door"
    case ELEVATOR = "elevator"
    case ESCALATOR = "escalator"
    case FAREGATES = "faregates"
    case FENCE = "fence"
    case FIRE_HYDRANT = "fire_hydrant"
    case FLAG = "flag"
    case GUARDRAIL = "guardrail"
    case HANDRAIL = "handrail"
    case MONUMENT = "monument"
    case MOTORBIKE = "motorbike"
    case OTHER = "other"
    case PERSON = "person"
    case POLE = "pole"
    case POSTBOX = "postbox"
    case SAFETY_CONE = "safety-cone"
    case SHRUBS = "shrubs"
    case SIGNAL_BLUE = "signal_blue"
    case SIGNAL_BUTTON = "signal_button"
    case SIGNAL_RED = "signal_red"
    case SIGNBOARD = "signboard"
    case STAIRS = "stairs"
    case STEPS = "steps"
    case STOP_SIGN = "stop_sign"
    case TRAFFIC_LIGHT = "traffic_light"
    case TRAIN = "train"
    case TRAIN_TICKET_MACHINE = "train_ticket_machine"
    case TREE = "tree"
    case TRUCK = "truck"
    case VENDING_MACHINE = "vending_machine"
    case WALL = "wall"
    case WHITE_LINE = "white_line"
    
    static func fromString(_ string: String) -> ObstacleLabel {
        if let enumValue = ObstacleLabel(rawValue: string) {
            return enumValue
        } else {
            return .OTHER
        }
    }
    
    var obstacleClass: Obstacle {
        switch self {
            case .CAR, .TRUCK, .BUS, .MOTORBIKE, .TRAIN, .BOAT: return .VEHICLE
            case .BICYCLE, .BICYCLER: return .CYCLIST
            case .STAIRS, .STEPS, .ESCALATOR, .ELEVATOR: return .STAIRS
            case .SAFETY_CONE: return .CONSTRUCTION
            case .WALL, .DOOR: return .WALL
            case .FENCE: return .FENCE
            case .GUARDRAIL, .FAREGATES, .HANDRAIL, .FIRE_HYDRANT, .STOP_SIGN: return .BARRIER
            case .POLE, .BOLLARD, .MONUMENT: return .POLE
            case .TREE, .SHRUBS: return .TREE
            case .PERSON: return .PERSON
            default: return .NONE
        }
    }
}
    
