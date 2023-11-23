import Foundation
import AVFoundation
import CoreImage
import Accelerate
import Vision

enum ConfigurationError: Error {
    case lidarDeviceUnavailable
    case requiredFormatUnavailable
}

class CameraDepthController: NSObject {
    // Configuring depth properties
    var depthConfiguration: DepthConfiguration = DepthConfiguration(useEstimation: true)
    var isFilteringEnabled = true {
        didSet {
            if (depthDataOutput != nil) {
                depthDataOutput.isFilteringEnabled = isFilteringEnabled
            }
        }
    }
    
    // Properties for AV capture
    private let preferredWidthResolution = 1920
    private let videoQueue = DispatchQueue(label: "com.ClarifEye.VideoQueue", qos: .userInteractive)
    
    private(set) var captureSession: AVCaptureSession!
    private var depthDataOutput: AVCaptureDepthDataOutput!
    private var videoDataOutput: AVCaptureVideoDataOutput!
    private var outputVideoSync: AVCaptureDataOutputSynchronizer!
    
    // Set up for Metal textures
    private var textureCache: CVMetalTextureCache!
    
    // Delegates
    var cameraDepthDelegate: CameraDepthReceiver?
    var cameraCapturedDataDelegate: CameraCapturedDataReceiver?
     
    override init() {
        super.init()

        
        do {
            #if !targetEnvironment(simulator)
            try setupSession()
            #endif
        } catch {
            fatalError("Unable to configure the capture session.")
        }
    }
    
    
    // MARK: Initialization
    private func setupSession() throws {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .inputPriority

        // Configure the capture session.
        captureSession.beginConfiguration()
        
        try setupCaptureInput()
        setupCaptureOutputs()
        
        // Finalize the capture session configuration.
        captureSession.commitConfiguration()
    }
    
    private func setupCaptureInput() throws {
        // Look up the LiDAR camera.
        guard let device = AVCaptureDevice.default(.builtInLiDARDepthCamera, for: .video, position: .back) else {
            throw ConfigurationError.lidarDeviceUnavailable
        }
        
        // Find a match that outputs video data in the format the app's custom Metal views require.
        guard let format = (device.formats.last { format in
            format.formatDescription.dimensions.width == preferredWidthResolution &&
            format.formatDescription.mediaSubType.rawValue == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange &&
            !format.isVideoBinned &&
            !format.supportedDepthDataFormats.isEmpty
        }) else {
            throw ConfigurationError.requiredFormatUnavailable
        }
        
        // Find a match that outputs depth data in the format the app's custom Metal views require.
        guard let depthFormat = (format.supportedDepthDataFormats.last { depthFormat in
            depthFormat.formatDescription.mediaSubType.rawValue == kCVPixelFormatType_DepthFloat16
        }) else {
            throw ConfigurationError.requiredFormatUnavailable
        }
        
        // Begin the device configuration.
        try device.lockForConfiguration()

        // Configure the device and depth formats.
        device.activeFormat = format
        device.activeDepthDataFormat = depthFormat

        // Finish the device configuration.
        device.unlockForConfiguration()
        
        print("Selected video format: \(device.activeFormat)")
        print("Selected depth format: \(String(describing: device.activeDepthDataFormat))")
        
        // Add a device input to the capture session.
        let deviceInput = try AVCaptureDeviceInput(device: device)
        captureSession.addInput(deviceInput)
    }
    
    private func setupCaptureOutputs() {
        // Create an object to output video sample buffers.
        videoDataOutput = AVCaptureVideoDataOutput()
        if (depthConfiguration.videoFormat == VideoFormat.BGRA_32) {
            videoDataOutput.videoSettings = [
                String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32BGRA)
            ]
        }
        
        captureSession.addOutput(videoDataOutput)
        
        // Create an object to output depth data.
        depthDataOutput = AVCaptureDepthDataOutput()
        depthDataOutput.isFilteringEnabled = isFilteringEnabled
        captureSession.addOutput(depthDataOutput)

        // Create an object to synchronize the delivery of depth and video data.
        outputVideoSync = AVCaptureDataOutputSynchronizer(dataOutputs: [depthDataOutput, videoDataOutput])
        outputVideoSync.setDelegate(self, queue: videoQueue)

        // Enable camera intrinsics matrix delivery.
        guard let outputConnection = videoDataOutput.connection(with: .video) else { return }
        if outputConnection.isCameraIntrinsicMatrixDeliverySupported {
            outputConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
        }
    }
    
    func startStream() {
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }
    
    func stopStream() {
        captureSession.stopRunning()
    }
    
}

extension CameraDepthController: AVCaptureDataOutputSynchronizerDelegate {
    
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer,
                                didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
        
        var depthConfiguration: DepthConfiguration = cameraCapturedDataDelegate?.depthConfiguration ?? DepthConfiguration()
        
        // Retrieve the synchronized depth and sample buffer container objects.
        guard let syncedDepthData = synchronizedDataCollection.synchronizedData(for: depthDataOutput) as? AVCaptureSynchronizedDepthData,
              let syncedVideoData = synchronizedDataCollection.synchronizedData(for: videoDataOutput) as? AVCaptureSynchronizedSampleBufferData else { return }
        
        guard let pixelBuffer = syncedVideoData.sampleBuffer.imageBuffer,
              let cameraCalibrationData = syncedDepthData.depthData.cameraCalibrationData else { return }
    
        // Handle the classifictions
        do {
            if let imagePixelBuffer = syncedVideoData.sampleBuffer.imageBuffer {
                if (depthConfiguration.useEstimation) {
                    cameraDepthDelegate?.classifyWithDepthEstimation(imagePixelBuffer: imagePixelBuffer)
                } else {
                    var depthPixelBuffer = syncedDepthData.depthData.depthDataMap
                    cameraDepthDelegate?.classifyWithLidar(imagePixelBuffer: imagePixelBuffer, depthDataBuffer: depthPixelBuffer)
                }
            }
        }


        // Handle metal textures
        var textures: [MTLTexture?]
        if (depthConfiguration.videoFormat == VideoFormat.BGRA_32) {
            textures = [pixelBuffer.texture(withFormat: .bgra8Unorm, planeIndex: 0, addToCache: textureCache)]
        } else {
            textures = [
                pixelBuffer.texture(withFormat: .r8Unorm, planeIndex: 0, addToCache: textureCache),
                pixelBuffer.texture(withFormat: .rg8Unorm, planeIndex: 1, addToCache: textureCache)
            ]
        }
        let data = CameraCapturedData(depth: syncedDepthData.depthData.depthDataMap.texture(withFormat: .r16Float, planeIndex: 0, addToCache: textureCache),
                      colorY: textures,
                      cameraIntrinsics: cameraCalibrationData.intrinsicMatrix,
                      cameraReferenceDimensions: cameraCalibrationData.intrinsicMatrixReferenceDimensions)

        cameraCapturedDataDelegate?.onNewData(capturedData: data)
    }
}
