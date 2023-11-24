import SwiftUI

struct ClassificationTextView: View {
    @ObservedObject var manager: CameraDepthManager
    
    var body: some View {
        VStack {
            Text("Classification Text")
            let arClassification = manager.arController.classification
            if (arClassification != nil ) {
                let classification = arClassification!
                let text = "\(classification.label), \(classification.distance)m away, confidence: \(classification.confidence)"
                    
                Text(text)
            }
        }.frame(minHeight: 200)
    }
}
