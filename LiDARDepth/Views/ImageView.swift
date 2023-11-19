import SwiftUI
import MetalKit
import Metal

struct ImageView: View {
    
    @ObservedObject var manager: CameraManager
    @Binding var maxDepth: Float
    @Binding var minDepth: Float
    
    
    var body: some View {
        VStack {
            
            Button(action: manager.toggleStream) {
                Text(manager.waitingForCapture ? "Start video" : "Stop video")
            }
           
            ScrollView {
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
    }
}
