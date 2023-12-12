import SwiftUI

struct StatusView: View {
    @ObservedObject var manager: CameraManager
    
    var body: some View {
        let showText = manager.showText
        let text = manager.message
        VStack {
            if showText {
                VStack { 
                    Text(text)
                    .transition(.opacity)
                    .foregroundColor(Color.white)
                } 
                .padding()
                .background(Color.black.opacity(0.5))
            }
        }
        .animation(.default, value: showText)
    }
}
