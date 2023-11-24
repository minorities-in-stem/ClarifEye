import SwiftUI
import MetalKit
import Metal

struct ContentView: View {
    @State private var settings: Settings
    @State private var cameraDepthManager: CameraDepthManager
    
    init() {
        cameraDepthManager = CameraDepthManager()
        settings = Settings()
        settings.cameraDepthManager = cameraDepthManager
    }
    
    var body: some View {
        TabView {
            ImageView(settings: settings, manager: cameraDepthManager)
                .tabItem {
                    Label("Vision", systemImage: "eyeglasses")
                }
            SettingsView(settings: settings)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }

        }
    }
}
