import Foundation

func performSmoothing(data: [Float], alpha: Float) -> Float? {
    guard !data.isEmpty else { return nil }
    guard data.count > 1 else { return data.first }

    var smoothedValue = data.first!
    for currentValue in data {
        smoothedValue = alpha * currentValue + (1 - alpha) * smoothedValue
    }
    return smoothedValue
}
