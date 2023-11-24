import SwiftUI
import MetalKit
import Metal

struct SettingsView: View {
    @Binding var settings: Settings
    
    let maxRangeDepth = Float(15)
    let minRangeDepth = Float(0)
    
    let minRangeOpacity = Float(0)
    let maxRangeOpacity = Float(1)
    
    
    var body: some View {
        List {
            Section(header: Text("Depth Settings")) {
                HStack {
                    Text("Use Depth Estimation")
                    Toggle("Use Depth Estimation", isOn: $settings.useDepthEstimation).labelsHidden()
                }
                
                HStack {
                    Text("Depth Filtering")
                    Toggle("Depth Filtering", isOn: $settings.isFilteringDepth).labelsHidden()
                }
                
                SliderDepthBoundaryView(
                    val: $settings.maxDepth, label: "Max Depth",
                    minVal: minRangeDepth,
                    maxVal: maxRangeDepth,
                    disabled: !settings.isFilteringDepth
                )
                SliderDepthBoundaryView(
                    val: $settings.minDepth, label: "Min Depth",
                    minVal: minRangeDepth,
                    maxVal: maxRangeDepth,
                    disabled: !settings.isFilteringDepth
                )
                SliderDepthBoundaryView(
                    val: $settings.depthFilterOpacity, label: "Filtering Overlay Opacity",
                    minVal: minRangeOpacity,
                    maxVal: maxRangeOpacity,
                    disabled: !settings.isFilteringDepth
                )
            }
        }
    }
}
