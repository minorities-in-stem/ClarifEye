import Foundation

enum MeasurementSystem: String {
    case Metric = "Metric (m)"
    case Imperial = "Imperial (ft)"
}

class Settings: ObservableObject {
    @Published var measurementSystem: MeasurementSystem = MeasurementSystem.Metric
    @Published var audioOutput: Bool = true
    @Published var audioSpeed: Float = 0.5
}
