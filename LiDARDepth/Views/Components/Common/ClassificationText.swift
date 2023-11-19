import SwiftUI

struct ClassificationTextView: View {
    @ObservedObject var manager: CameraManager
    
    var body: some View {
            VStack {
                List {
                    Text("Classification Text")
                    ForEach(manager.classifications.indices, id: \.self) { index in
                        let classification = manager.classifications[index]
                        let text = "\(classification.label), \(classification.distance)m away, confidence: \(classification.confidence)"
                        
                        Text(text)
                    }
                }.frame(minHeight: 200)
                
            }
    }
}
