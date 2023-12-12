import Foundation
import SwiftUI
import Combine
import simd
import AVFoundation

protocol CameraCapturedDataReceiver: AnyObject {
    
}

protocol StatusViewManagerDelegate: AnyObject {
    func onMessage(message: String)
    func onShowText(showText: Bool)
}


class CameraManager: ObservableObject, CameraCapturedDataReceiver, StatusViewManagerDelegate {
    @Published var orientation = UIDevice.current.orientation
    @Published var waitingForCapture = false
    @Published var dataAvailable = false
    
    var cancellables = Set<AnyCancellable>()
    
    @Published var arController: ARController = ARController()
    @Published var statusViewManager: StatusViewManager = StatusViewManager()
    
    @Published var message: String = "Hello!"
    @Published var showText: Bool = true
    
    init() {
        // Set up the controllers and assign their delegates
        arController.classificationController.classificationDelegate = arController
        arController.statusViewManager = statusViewManager
        
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification).sink { _ in
            self.orientation = UIDevice.current.orientation
        }.store(in: &cancellables)
        
        arController.cameraCapturedDataDelegate = self
        statusViewManager.delegate = self
    }
    
    func onMessage(message: String) {
        DispatchQueue.main.async {
            self.message = message
        }
    }
    
    func onShowText(showText: Bool) {
        DispatchQueue.main.async {
            self.showText = showText
        }
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
 
