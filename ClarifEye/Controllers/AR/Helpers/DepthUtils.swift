import Foundation
import Accelerate

func performSmoothing(data: [Float], alpha: Float) -> [Float]? {
    guard !data.isEmpty else { return nil }
    guard data.count > 1 else { return data }
    
    var arr = data
    
    let timePoints = 5
    if (data.count < timePoints) {
        let lastElement = data[data.count-1]
        let padding = Array(repeating: lastElement, count: timePoints - data.count)
        arr = arr + padding
        
    }
    let convolved = vDSP.convolve(arr[..<timePoints], withKernel:  [0.2, 0.2, 0.2, 0.2, 0.2])
    
    return convolved
}
