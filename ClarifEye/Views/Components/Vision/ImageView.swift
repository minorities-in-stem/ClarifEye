import SwiftUI

struct ImageView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var manager: CameraDepthManager
    
    var body: some View {
        ZStack {
            ButtonSettingsView(manager: manager)
                .zIndex(1000)

            VStack {
                ClassificationTextView(manager: manager)
                    .padding(.top, 20)
                Spacer()
            }

            ARView(manager: manager)
                .zIndex(-1)
        }
    }
}

struct ButtonSettingsView: View {
    @ObservedObject var manager: CameraDepthManager
    
    var body: some View {
        VStack {
            Spacer() // Pushes everything to the bottom

            HStack {
                VStack(alignment: .leading, spacing: 10) {
                    Button(action: manager.toggleStream) {
                        if (manager.waitingForCapture) {
                            Image(systemName: "play.circle")
                        } else {
                            Image(systemName: "pause.circle")
                        }
                    }
                    
                    Button(action: manager.restart) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .padding(.leading, 20) // Add padding to align with the screen's edge

                Spacer() // Pushes VStack to the left
            }
            .padding(.bottom, 150)
        }
    }
}
