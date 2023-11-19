import SwiftUI
import UIKit

struct BoundingBox: View {
    
    @ObservedObject var manager: CameraManager
    var frameSize: CGSize
    
    var body: some View {
        Group {
            if manager.dataAvailable {
                ForEach(manager.classifications.indices, id: \.self) { index in
                    let boundingBox = manager.classifications[index].boundingBox
                    Rectangle()
                        .path(in: boundingBox)
                        .stroke(Color.red, lineWidth: 2)
                    
                    BoundingBoxView(boundingBox: boundingBox, parentSize: frameSize)
                }
            }
        }
    }
}


struct BoundingBoxView: View {
    // This represents the normalized bounding box, typically from the Core ML model
    var boundingBox: CGRect

    // The size of the view where the bounding box will be drawn
    var parentSize: CGSize

    var body: some View {
        // Convert the bounding box to the coordinate space of the view
        let frame = CGRect(x: boundingBox.origin.x * parentSize.width,
                           y: (1 - boundingBox.origin.y - boundingBox.height) * parentSize.height,
                           width: boundingBox.width * parentSize.width,
                           height: boundingBox.height * parentSize.height)

        // Draw the rectangle (or just the lines) based on the converted frame
        Rectangle()
            .path(in: frame)
            .stroke(lineWidth: 2)
            .foregroundColor(.red)
            // Position the rectangle within the parent view
            .offset(x: frame.minX, y: frame.minY)
            .animation(.linear, value: boundingBox)
    }
}
