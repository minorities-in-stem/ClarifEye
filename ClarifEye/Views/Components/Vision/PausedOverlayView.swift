import SwiftUI

struct PausedOverlayView: View {
    @State var message: String?
    @State var initializing: Bool?
    
    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Image(systemName: "pause.fill").font(.system(size: 60))
            if (message != nil) {
                Text(message!)
                    .font(.system(size: 40))
                    .multilineTextAlignment(.center)
            } else {
                Text("Paused").font(.system(size: 40))
            }
        }
        .frame(minWidth: 0,
           maxWidth: .infinity,
           minHeight: 0,
           maxHeight: .infinity,
           alignment: .center)
        .background(Color.gray.opacity(0.6))
    }
}
