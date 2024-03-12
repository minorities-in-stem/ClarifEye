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
                    .font(.system(size: 24))
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .cornerRadius(4)
            }
        }
        .animation(.default, value: showText)
    }
}
