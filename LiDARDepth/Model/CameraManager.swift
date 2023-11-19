import Foundation
import SwiftUI
import Combine
import simd
import AVFoundation

class CameraManager: ObservableObject, CaptureDataReceiver {

    var capturedData: CameraCapturedData
    @Published var isFilteringDepth: Bool {
        didSet {
            controller.isFilteringEnabled = isFilteringDepth
        }
    }
    
    @Published var useDepthEstimation: Bool = false {
        didSet {
            controller.useDepthEstimation = useDepthEstimation
        }
    }
    @Published var orientation = UIDevice.current.orientation
    @Published var waitingForCapture = true
    @Published var dataAvailable = false
    
    @Published var classifications: [ClassificationData] = []
    
    let controller: CameraController
    var cancellables = Set<AnyCancellable>()
    var session: AVCaptureSession { controller.captureSession }
    
    init() {
        // Create an object to store the captured data for the views to present.
        capturedData = CameraCapturedData()
        controller = CameraController()
        controller.isFilteringEnabled = true
        isFilteringDepth = controller.isFilteringEnabled
        
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification).sink { _ in
            self.orientation = UIDevice.current.orientation
        }.store(in: &cancellables)
        controller.delegate = self
    }
    
    func toggleStream() {
        if (waitingForCapture) {
            controller.startStream()
            waitingForCapture = false
        } else {
            controller.stopStream()
            waitingForCapture = true
        }

    }
    
    func onNewData(capturedData: CameraCapturedData) {
        DispatchQueue.main.async {
            // Because the views hold a reference to `capturedData`, the app updates each texture separately.
            self.capturedData.depth = capturedData.depth
            self.capturedData.colorY = capturedData.colorY
            self.capturedData.colorCbCr = capturedData.colorCbCr
            self.capturedData.cameraIntrinsics = capturedData.cameraIntrinsics
            self.capturedData.cameraReferenceDimensions = capturedData.cameraReferenceDimensions
            if self.dataAvailable == false {
                self.dataAvailable = true
            }
        }
    }
    
    func onClassification(classifications: [ClassificationData]) {
        DispatchQueue.main.async {
            self.classifications = classifications
            self.objectWillChange.send()
        }
    }
}
 
