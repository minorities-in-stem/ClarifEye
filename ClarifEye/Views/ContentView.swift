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
                .onTapGesture {
                    self.cameraManager.startStream()
                }
            SettingsView(settings: settings)
                .onTapGesture {
                    self.cameraManager.stopStream()
                }
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }

        }
        .zIndex(1000)
        .background(Color.black.opacity(0.5))
    }
}
