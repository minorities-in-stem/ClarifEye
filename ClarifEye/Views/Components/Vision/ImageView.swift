import SwiftUI

struct ImageView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var manager: CameraManager
    
    var body: some View {
        ZStack {
            ButtonSettingsView(manager: manager)
                .zIndex(1000)

            VStack {
                StatusView(
//                    showText: manager.showText,
//                    text: manager.message
                    manager: manager
                )
                .padding(.top, 20)
                .zIndex(1000)
                
                Spacer()
            }

            ARView(manager: manager)
                .zIndex(-1)
        }
    }
}

struct ButtonSettingsView: View {
    @ObservedObject var manager: CameraManager
    private let buttonSize = CGFloat(30)
    
    var body: some View {
        VStack {
            Spacer() // Pushes everything to the bottom

            HStack {
                VStack(alignment: .leading, spacing: 10) {
                    Button(action: manager.toggleStream) {
                        if (manager.waitingForCapture) {
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
