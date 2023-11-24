import Foundation
import SwiftUI
import Combine
import simd
import AVFoundation

protocol CameraCapturedDataReceiver: AnyObject {

}


class CameraDepthManager: ObservableObject, CameraCapturedDataReceiver {
    @Published var orientation = UIDevice.current.orientation
    @Published var waitingForCapture = true
    @Published var dataAvailable = false
    
    var cancellables = Set<AnyCancellable>()

    @Published var classificationController: ClassificationController = ClassificationController()
    @Published var arController: ARController = ARController()
    
    init() {
        // Set up the controllers and assign their delegates
        classificationController.classificationDelegate = arController
        arController.cameraDepthDelegate = classificationController
        arController.cameraCapturedDataDelegate = self
        
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification).sink { _ in
            self.orientation = UIDevice.current.orientation
        }.store(in: &cancellables)
    }
    
    func startStream() {
        waitingForCapture = false
        arController.start()
    }
    
    func stopStream() {
        waitingForCapture = true
        arController.pause()
    }
    
    func toggleStream() {
        if (waitingForCapture) {
            startStream()
        } else {
            stopStream()
        }
    }
    
    func restart() {
        arController.restartSession()
    }
}
 
