import SwiftUI
import MetalKit
import Metal

struct ContentView: View {
    @State private var maxDepth = Float(15)
    @State private var minDepth = Float(0.0)
    @StateObject private var manager = CameraManager()
    
    var body: some View {
        TabView {
            ImageView(manager: manager, maxDepth: $maxDepth, minDepth: $minDepth)
                .badge(2)
                .tabItem {
                    Label("Vision", systemImage: "eyeglasses")
                }
            SettingsView(manager: manager, maxDepth: $maxDepth, minDepth: $minDepth)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }

        }
    }
}
