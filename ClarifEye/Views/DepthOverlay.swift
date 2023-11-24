import SwiftUI

struct DepthOverlay: View {
    
    @ObservedObject var manager: CameraDepthManager
    @Binding var opacity: Float
    @Binding var maxDepth: Float
    @Binding var minDepth: Float
    
    var body: some View {
        if manager.dataAvailable {
            VStack {
                ZStack {
                    MetalTextureViewColor(
                        rotationAngle: rotationAngle,
                        capturedData: manager.capturedData,
                        depthConfiguration: manager.depthConfiguration
                    )
                    MetalTextureDepthView(
                        rotationAngle: rotationAngle,
                        maxDepth: $maxDepth,
                        minDepth: $minDepth,
                        capturedData: manager.capturedData
                    )
                        .opacity(Double(opacity))
                    
                    GeometryReader { geometry in
                        BoundingBoxManager(manager: manager, frameSize: geometry.size)
                    }
                }
            }
        }
    }
}
