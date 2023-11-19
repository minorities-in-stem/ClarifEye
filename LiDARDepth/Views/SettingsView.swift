import SwiftUI
import MetalKit
import Metal

struct SettingsView: View {
    @ObservedObject var manager: CameraManager
    @Binding var maxDepth: Float
    @Binding var minDepth: Float
    
    let maxRangeDepth = Float(15)
    let minRangeDepth = Float(0)
    
    
    var body: some View {
        VStack {
            Section(header: Text("Depth Settings")) {
                HStack {
                    Text("Use Depth Estimation")
                    Toggle("Use Depth Estimation", isOn: $manager.useDepthEstimation).labelsHidden()
                }
                Spacer()
                
                
                HStack {
                    Text("Depth Filtering")
                    Toggle("Depth Filtering", isOn: $manager.isFilteringDepth).labelsHidden()
                }
                
                SliderDepthBoundaryView(val: $maxDepth, label: "Max Depth", minVal: minRangeDepth, maxVal: maxRangeDepth)
                SliderDepthBoundaryView(val: $minDepth, label: "Min Depth", minVal: minRangeDepth, maxVal: maxRangeDepth)
                Spacer()
            }
        }
    }
}


struct SliderDepthBoundaryView: View {
    @Binding var val: Float
    var label: String
    var minVal: Float
    var maxVal: Float
    let stepsCount = Float(200.0)
    var body: some View {
        VStack {
            HStack {
                Text(String(format: " %@: %.2f", label, val))
            }
            Slider(
                value: $val,
                in: minVal...maxVal,
                step: (maxVal - minVal) / stepsCount
            ) {
            } minimumValueLabel: {
                Text(String(minVal))
            } maximumValueLabel: {
                Text(String(maxVal))
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewDevice("iPhone 15 Pro")
    }
}
