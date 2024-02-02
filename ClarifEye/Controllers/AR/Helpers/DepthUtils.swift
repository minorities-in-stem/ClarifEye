import Foundation
import Accelerate

func performSmoothing(data: [Float], alpha: Float) -> [Float]? {
    guard !data.isEmpty else { return nil }
    guard data.count > 1 else { return data }

    var smoothedValue = data.first!
    
    var timePoints = 5
    let convTimes = vDSP.convolve(data[0...timePoints], withKernel: [0.2, 0.2, 0.2, 0.2, 0.2])
    
    return convTimes
}
