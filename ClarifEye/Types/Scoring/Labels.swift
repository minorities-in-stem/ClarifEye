import Foundation

enum ObstacleLabel: Int {
    case PERSON = 0
    case BICYCLE = 1
    case CAR = 2
    case MOTORBIKE = 3
    case BUS = 4
    case TRAIN = 5
    case TRUCK = 6
    case BOAT = 7
    case TRAFFIC_LIGHT = 8
    case BICYCLER = 9
    case BRAILLE_BLOCK = 10
    case GUARDRAIL = 11
    case WHITE_LINE = 12
    case CROSSWALK = 13
    case SIGNAL_BUTTON = 14
    case SIGNAL_RED = 15
    case SIGNAL_BLUE = 16
    case STAIRS = 17
    case HANDRAIL = 18
    case STEPS = 19
    case FAREGATES = 20
    case TRAIN_TICKET_MACHINE = 21
    case SHRUBS = 22
    case TREE = 23
    case VENDING_MACHINE = 24
    case BATHROOM = 25
    case DOOR = 26
    case ELEVATOR = 27
    case ESCALATOR = 28
    case BOLLARD = 29
    case BUS_STOP_SIGN = 30
    case POLE = 31
    case MONUMENT = 32
    case FENCE = 33
    case WALL = 34
    case SIGNBOARD = 35
    case FLAG = 36
    case POSTBOX = 37
    case SAFETY_CONE = 38
    case DOG = 39
    case FIRE_HYDRANT = 40
    
    var description: String {
        switch self {
            case .PERSON: return "person"
            case .BICYCLE: return "bicycle"
            case .CAR: return "car"
            case .MOTORBIKE: return "motorbike"
            case .BUS: return "bus"
            case .TRAIN: return "train"
            case .TRUCK: return "truck"
            case .BOAT: return "boat"
            case .TRAFFIC_LIGHT: return "traffic_light"
            case .BICYCLER: return "bicycler"
            case .BRAILLE_BLOCK: return "braille_block"
            case .GUARDRAIL: return "guardrail"
            case .WHITE_LINE: return "white_line"
            case .CROSSWALK: return "crosswalk"
            case .SIGNAL_BUTTON: return "signal_button"
            case .SIGNAL_RED: return "signal_red"
            case .SIGNAL_BLUE: return "signal_blue"
            case .STAIRS: return "stairs"
            case .HANDRAIL: return "handrail"
            case .STEPS: return "steps"
            case .FAREGATES: return "faregates"
            case .TRAIN_TICKET_MACHINE: return "train_ticket_machine"
            case .SHRUBS: return "shrubs"
            case .TREE: return "tree"
            case .VENDING_MACHINE: return "vending_machine"
            case .BATHROOM: return "bathroom"
            case .DOOR: return "door"
            case .ELEVATOR: return "elevator"
            case .ESCALATOR: return "escalator"
            case .BOLLARD: return "bollard"
            case .BUS_STOP_SIGN: return "bus_stop_sign"
            case .POLE: return "pole"
            case .MONUMENT: return "monument"
            case .FENCE: return "fence"
            case .WALL: return "wall"
            case .SIGNBOARD: return "signboard"
            case .FLAG: return "flag"
            case .POSTBOX: return "postbox"
            case .SAFETY_CONE: return "safety-cone"
            case .DOG: return "dog"
            case .FIRE_HYDRANT: return "fire_hydrant"
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
    