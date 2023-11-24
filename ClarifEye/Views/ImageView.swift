import SwiftUI

struct ImageView: View {
    @ObservedObject var settings: Settings
    
    var body: some View {
        let manager = settings.cameraDepthManager
        ZStack {
            ButtonSettingsView(manager: manager)

            if (!manager.waitingForCapture && manager.dataAvailable) {
                VStack {
                    ClassificationTextView(manager: manager)
                        .padding(.top, 20)
                    Spacer()
                }


                if manager.dataAvailable {
                    DepthOverlay(manager: manager,
                                 opacity: $settings.depthFilterOpacity,
                                 maxDepth: $settings.maxDepth,
                                 minDepth: $settings.minDepth
                    )
                    .aspectRatio(calcAspect(orientation: viewOrientation, texture: manager.capturedData.depth), contentMode: .fit)
                    
                    ARView(settings: settings)
//                        .edgesIgnoringSafeArea(.all)
                        .frame(height: 400)
                }
            } else {
                Text("Recording paused")
            }
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
                    
                }
                .padding(.leading, 20) // Add padding to align with the screen's edge

                Spacer() // Pushes VStack to the left
            }
            .padding(.bottom, 150)
        }
    }
}
