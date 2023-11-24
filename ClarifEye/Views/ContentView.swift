import SwiftUI
import MetalKit
import Metal

struct ContentView: View {
    @StateObject private var settings: Settings = Settings()
    @StateObject private var cameraManager: CameraManager = CameraManager()
    
    var body: some View {
        TabView {
            ImageView(settings: settings, manager: cameraManager)
                .tabItem {
                    Label("Vision", systemImage: "eyeglasses")
                }
            SettingsView(settings: settings)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }

        }
        .zIndex(1000)
        .background(Color.black.opacity(0.5))
    }
}
