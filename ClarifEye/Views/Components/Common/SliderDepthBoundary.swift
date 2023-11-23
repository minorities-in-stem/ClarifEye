import SwiftUI

struct SliderDepthBoundaryView: View {
    @Binding var val: Float
    var label: String
    var minVal: Float
    var maxVal: Float
    var disabled: Bool?
    let stepsCount = Float(200.0)
    
    var body: some View {
        VStack {
            Text(String(format: " %@: %.2f", label, val))
            
            Slider(
                value: $val,
                in: minVal...maxVal,
                step: (maxVal - minVal) / stepsCount
            ) {
            } minimumValueLabel: {
                Text(String(minVal))
            } maximumValueLabel: {
                Text(String(maxVal))
            }.disabled(disabled ?? false)
        }
    }
}
