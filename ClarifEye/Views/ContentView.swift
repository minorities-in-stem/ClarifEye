import SwiftUI
import MetalKit
import Metal

struct ContentView: View {
    @State private var maxDepth = Float(15)
    @State private var minDepth = Float(0.0)
    @State private var depthFilterOpacity = Float(0.0)
    @StateObject private var manager = CameraDepthManager()
    
    var body: some View {
        TabView {
            ImageView(manager: manager, maxDepth: $maxDepth, minDepth: $minDepth, depthFilterOpacity: $depthFilterOpacity)
                .tabItem {
                    Label("Vision", systemImage: "eyeglasses")
                }
            SettingsView(manager: manager, maxDepth: $maxDepth, minDepth: $minDepth, depthFilterOpacity: $depthFilterOpacity)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }

        }
    }
}
