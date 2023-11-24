import Foundation
import SwiftUI
import Combine
import simd
import AVFoundation

protocol CameraCapturedDataReceiver: AnyObject {
    func onNewData(capturedData: CameraCapturedData)
    var orientation: UIDeviceOrientation {
        get
    }
    var depthConfiguration: DepthConfiguration {
        get
    }
}


class CameraDepthManager: ObservableObject, CameraCapturedDataReceiver {
    @Published var orientation = UIDevice.current.orientation
    @Published var waitingForCapture = true
    @Published var dataAvailable = false
    @Published var depthConfiguration: DepthConfiguration = DepthConfiguration()
    
    @Published var isFilteringDepth: Bool = true {
        didSet {
            controller.isFilteringEnabled = isFilteringDepth
        }
    }
    @Published var useDepthEstimation: Bool = DepthConfiguration().useEstimation {
        didSet {
            depthConfiguration = DepthConfiguration(useEstimation: useDepthEstimation)
            controller.depthConfiguration = depthConfiguration
        }
    }
    
    var cancellables = Set<AnyCancellable>()
    @Published var capturedData: CameraCapturedData = CameraCapturedData()
    
    @Published var controller: CameraDepthController = CameraDepthController()
    @Published var classificationController: ClassificationController = ClassificationController()
    @Published var arController: ARController = ARController()
    init() {
        // Set up the controllers and assign their delegates
        classificationController.classificationDelegate = arController
        
        controller.isFilteringEnabled = true
        controller.cameraDepthDelegate = classificationController
        
        isFilteringDepth = controller.isFilteringEnabled
        depthConfiguration = controller.depthConfiguration
        useDepthEstimation = controller.depthConfiguration.useEstimation
        
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification).sink { _ in
            self.orientation = UIDevice.current.orientation
        }.store(in: &cancellables)
        
        controller.cameraCapturedDataDelegate = self
    }
    
    func startStream() {
        controller.startStream()
        waitingForCapture = false
    }
    
    func stopStream() {
        controller.stopStream()
        waitingForCapture = true
    }
    
    func toggleStream() {
        if (waitingForCapture) {
            startStream()
        } else {
            stopStream()
        }

    }
    
    func onNewData(capturedData: CameraCapturedData) {
        DispatchQueue.main.async {
            // Because the views hold a reference to `capturedData`, the app updates each texture separately.
            self.capturedData.depth = capturedData.depth
            self.capturedData.colorY = capturedData.colorY
            self.capturedData.cameraIntrinsics = capturedData.cameraIntrinsics
            self.capturedData.cameraReferenceDimensions = capturedData.cameraReferenceDimensions
            if self.dataAvailable == false {
                self.dataAvailable = true
            }
        }
    }
}
 
