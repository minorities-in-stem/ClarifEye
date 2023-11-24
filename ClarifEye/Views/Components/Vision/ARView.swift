import SwiftUI
import ARKit
import SpriteKit

struct ARViewWrapper: UIViewControllerRepresentable {
    @ObservedObject var manager: CameraDepthManager
    
    func makeUIViewController(context: Context) -> ARController  {
        let controller = manager.arController
        return controller
    }

    func updateUIViewController(_ uiViewController: ARController, context: Context) {
        // Update the view as needed
    }

    class Coordinator: NSObject {
        // Handle delegate callbacks if needdd
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}

// Usage in SwiftUI View
struct ARView: View {
    @ObservedObject var manager: CameraDepthManager
    
    var body: some View {
        ARViewWrapper(manager: manager)
    }
}
