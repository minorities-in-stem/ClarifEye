import SwiftUI

struct ImageView: View {
    @ObservedObject var manager: CameraManager
    var message = ""
    
    var body: some View {
        let paused = manager.streamPaused
        ZStack {
            ButtonSettingsView(manager: manager)
                .zIndex(1000)
            
            if (!paused) {
                VStack {
                    StatusView(manager: manager)
                    .padding(.top, 20)
                    .zIndex(1000)
                    
                    Spacer()
                }
            }

            ARView(manager: manager)
                .zIndex(-1)
        }
        .overlay {
            if (paused) {
                PausedOverlayView(
                    message: (!manager.initialized ? "Loading..." : manager.isError ? manager.message : nil)
                )
                .allowsHitTesting(false)
            }
        }
    }
}

struct ButtonSettingsView: View {
    @ObservedObject var manager: CameraManager
    private let buttonSize = CGFloat(45)
    var body: some View {
        VStack {
            Spacer() // Pushes everything to the bottom

            HStack {
                VStack(alignment: .leading, spacing: 15) {
                    Button(action: manager.toggleStream) {
                        if (manager.streamPaused) {
                            Image(systemName: "play.circle")
                                .font(.system(size: buttonSize))
                        } else {
                            Image(systemName: "pause.circle")
                                .font(.system(size: buttonSize))
                        }
                    }.controlSize(.large)
                    
                    Button(action: manager.restart) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: buttonSize))
                    }
                }
                .padding(.leading, 20) // Add padding to align with the screen's edge

                Spacer() // Pushes VStack to the left
            }
            .padding(.bottom, 150)
        }
    }
}
