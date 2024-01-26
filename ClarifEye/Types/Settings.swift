import Foundation

enum MeasurementSystem: String {
    case Metric = "Metric (m)"
    case Imperial = "Imperial (ft)"
}

class Settings: ObservableObject {
    var measurementSystem: MeasurementSystem = MeasurementSystem.Metric
    var audioOutput: Bool = true
    var audioSpeed: Float = 1
}
