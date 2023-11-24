import SwiftUI
import MetalKit
import Metal

struct ContentView: View {
    @StateObject private var settings = Settings()
    
    var body: some View {
        TabView {
            ImageView(settings: settings)
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
