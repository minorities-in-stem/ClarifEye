import SwiftUI

struct OverlayView: View {
    @State var paused: Bool?
    @State var loading: Bool?
    
    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            if (paused != nil && paused!) {
                Image(systemName: "pause.fill").font(.system(size: 60))
                Text("Paused").font(.system(size: 40))
            } else if (loading != nil && loading!) {
                Text("Loading...").font(.system(size: 40))
            }
        }
        .frame(minWidth: 0,
           maxWidth: .infinity,
           minHeight: 0,
           maxHeight: .infinity,
           alignment: .center)
        .background(Color.gray.opacity(0.4)) // TODO: change this to gray
    }
}
