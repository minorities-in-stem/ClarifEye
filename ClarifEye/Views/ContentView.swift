import SwiftUI
import MetalKit
import Metal

enum Tabs: String {
    case Vision = "Vision"
    case Settings = "Settings"
}

struct ContentView: View {
    @StateObject private var settings: Settings = Settings()
    @StateObject private var cameraManager: CameraManager = CameraManager()
    @State private var currentTab: Tabs = Tabs.Vision
    
    var body: some View {
        TabView(selection: $currentTab) {
            Group {
                ImageView(manager: cameraManager)
                    .tabItem {
                        Label(Tabs.Vision.rawValue, systemImage: "eyeglasses")
                    }
                    .tag(Tabs.Vision)
                SettingsView(settings: cameraManager.settings)
                    .tabItem {
                        Label(Tabs.Settings.rawValue, systemImage: "gear")
                    }
                    .tag(Tabs.Settings)
            }
            .toolbarColorScheme(.dark, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .onChange(of: currentTab) { tab in
                if (tab == Tabs.Settings) {
                    self.cameraManager.stopStream()
                } else if (tab == Tabs.Vision) {
                    self.cameraManager.startStream()
                }
            }
        }
        .zIndex(1000)
    }
}
