import SwiftUI

struct ImageView: View {
    
    @ObservedObject var manager: CameraManager
    @Binding var maxDepth: Float
    @Binding var minDepth: Float
    
    
    var body: some View {
        ZStack {
            Button(action: manager.toggleStream) {
                if (manager.waitingForCapture) {
                    Image(systemName: "play.circle")
                } else {
                    Image(systemName: "pause.circle")
                }
            }
           

            if (!manager.waitingForCapture && manager.dataAvailable) {
                ClassificationTextView(manager: manager)

                if manager.dataAvailable {
                    DepthOverlay(manager: manager,
                                 maxDepth: $maxDepth,
                                 minDepth: $minDepth
                    )
                    .aspectRatio(calcAspect(orientation: viewOrientation, texture: manager.capturedData.depth), contentMode: .fit)
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
}
