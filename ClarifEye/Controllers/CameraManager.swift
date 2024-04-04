import Foundation
import SwiftUI
import Combine
import simd
import AVFoundation

protocol CameraCapturedDataReceiver: AnyObject { 
    func setStreamAvailable(_ avail: Bool)
    func setInitialized(_ val: Bool)
}

protocol StatusViewManagerDelegate: AnyObject {
    func onMessage(_ message: String, isError: Bool)
    func onShowText(showText: Bool)
}


class CameraManager: ObservableObject, CameraCapturedDataReceiver, StatusViewManagerDelegate {
    @Published var orientation = UIDevice.current.orientation
    @Published var streamPaused = false
    @Published var dataAvailable = false
    
    var cancellables = Set<AnyCancellable>()
    
    @Published var settings: Settings = Settings()
    @Published var arController: ARController = ARController()
    @Published var statusViewManager: StatusViewManager = StatusViewManager()
    @Published var ttsManager: TTSManager = TTSManager()
    
    @Published var initialized: Bool = false
    @Published var message: String = "Welcome to ClarifEye!"
    @Published var isError: Bool = false
    @Published var showText: Bool = true
    @Published var reporting: Bool = false
    
    init() {
        // Set up the controllers and assign their delegates
        arController.classificationController.classificationDelegate = arController
        arController.statusViewManager = statusViewManager
        arController.ttsManager = ttsManager
        
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification).sink { _ in
            self.orientation = UIDevice.current.orientation
        }.store(in: &cancellables)
        
        arController.cameraCapturedDataDelegate = self
        statusViewManager.delegate = self
        
        ttsManager.settings = settings
        arController.settings = settings
    }
    
    func onMessage(_ message: String, isError: Bool = false) {
        self.message = message
        self.isError = isError
    }
    
    func onShowText(showText: Bool) {
        self.showText = showText
    }
    
    func setStreamAvailable(_ avail: Bool) {
        streamPaused = !avail
    }
    
    func setInitialized(_ val: Bool) {
        initialized = val
    }

    func startStream() {
        streamPaused = false
        arController.start()
    }
    
    func stopStream() {
        streamPaused = true
        arController.pause()
    }
    
    func toggleReporting() {
        arController.reporting = !arController.reporting
        self.reporting = arController.reporting
        
        if (self.reporting) {
            arController.recordStartTime()
        }
        
        if (!self.reporting) {
            arController.writeDataToFile()
        }
    }
    
    func toggleStream() {
        if (streamPaused) {
            startStream()
        } else {
            stopStream()
        }
    }
    
    func restart() {
        arController.restartSession()
    }
}
 
