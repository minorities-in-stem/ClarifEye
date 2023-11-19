import SwiftUI
import MetalKit
import Metal

struct SettingsView: View {
    @ObservedObject var manager: CameraManager
    @Binding var maxDepth: Float
    @Binding var minDepth: Float
    @Binding var depthFilterOpacity: Float
    
    let maxRangeDepth = Float(15)
    let minRangeDepth = Float(0)
    
    let minRangeOpacity = Float(0)
    let maxRangeOpacity = Float(1)
    
    
    var body: some View {
        List {
            Section(header: Text("Depth Settings")) {
                HStack {
                    Text("Use Depth Estimation")
                    Toggle("Use Depth Estimation", isOn: $manager.useDepthEstimation).labelsHidden()
                }
                
                HStack {
                    Text("Depth Filtering")
                    Toggle("Depth Filtering", isOn: $manager.isFilteringDepth).labelsHidden()
                }
                
                SliderDepthBoundaryView(
                    val: $maxDepth, label: "Max Depth",
                    minVal: minRangeDepth,
                    maxVal: maxRangeDepth,
                    disabled: !manager.isFilteringDepth
                )
                SliderDepthBoundaryView(
                    val: $minDepth, label: "Min Depth",
                    minVal: minRangeDepth,
                    maxVal: maxRangeDepth,
                    disabled: !manager.isFilteringDepth
                )
                SliderDepthBoundaryView(
                    val: $depthFilterOpacity, label: "Filtering Overlay Opacity",
                    minVal: minRangeOpacity,
                    maxVal: maxRangeOpacity,
                    disabled: !manager.isFilteringDepth
                )
            }
        }
    }
}
