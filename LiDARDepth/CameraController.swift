import Foundation
import AVFoundation
import CoreImage
import Accelerate
import Vision
import CoreML
import CoreVideo
import CoreImage


protocol CaptureDataReceiver: AnyObject {
    func onNewData(capturedData: CameraCapturedData)
    func onClassification(classifications: [ClassificationData])
}

class CameraController: NSObject, ObservableObject {
    
    enum ConfigurationError: Error {
        case lidarDeviceUnavailable
        case requiredFormatUnavailable
    }
    
    private let preferredWidthResolution = 1920
    
    private let videoQueue = DispatchQueue(label: "com.example.apple-samplecode.VideoQueue", qos: .userInteractive)
    
    private(set) var captureSession: AVCaptureSession!
    
    private var depthDataOutput: AVCaptureDepthDataOutput!
    private var videoDataOutput: AVCaptureVideoDataOutput!
    private var outputVideoSync: AVCaptureDataOutputSynchronizer!
    
    private var textureCache: CVMetalTextureCache!
    
    weak var delegate: CaptureDataReceiver?

    private let detectionModel: VNCoreMLModel
    private let depthModel: FCRNFP16
    
    var depthConfiguration: DepthConfiguration
    var isFilteringEnabled = true {
        didSet {
            if (depthDataOutput != nil) {
                depthDataOutput.isFilteringEnabled = isFilteringEnabled
            }
        }
    }
    
    override init() {
        depthConfiguration = DepthConfiguration(useEstimation: true)
        
        // Create a texture cache to hold sample buffer textures.
        CVMetalTextureCacheCreate(kCFAllocatorDefault,
                                  nil,
                                  MetalEnvironment.shared.metalDevice,
                                  nil,
                                  &textureCache)
        
        do {
            // Object Detection
            let detectionModelConfig = MLModelConfiguration()
            let yolo = try YOLOv3(configuration: detectionModelConfig)
//            let yolo = try YOLOv3Tiny(configuration: config)
//            let yolo = try Bacon(configuration: config)
            detectionModel = try VNCoreMLModel(for: yolo.model)
            
            // Depth Estimation
            let depthModelConfig = MLModelConfiguration()
            depthModel = try FCRNFP16(configuration: depthModelConfig)
        } catch {
            fatalError("Cannot load model")
        }
        
        super.init()

        
        do {
            #if !targetEnvironment(simulator)
            try setupSession()
            #endif
        } catch {
            fatalError("Unable to configure the capture session.")
        }
    }
    
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

// HELPER FUNCTIONS
extension CameraController {
    func downsample(pixelBuffer: CVPixelBuffer, toSize size: CGSize) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        
        // Create a downscaled version of the image
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: size.width / ciImage.extent.width, y: size.height / ciImage.extent.height))
        
        // Allocate a new pixel buffer to hold the downscaled image
        var newPixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, Int(size.width), Int(size.height), CVPixelBufferGetPixelFormatType(pixelBuffer), nil, &newPixelBuffer)
        
        // Render the downscaled image to the new pixel buffer
        if let newPixelBuffer = newPixelBuffer {
            context.render(scaledImage, to: newPixelBuffer)
            return newPixelBuffer
        }
        
        return nil
    }
    
    func denormalizeBoundingBox(boundingBox: CGRect, colorImageSize: CGSize) -> CGRect {
        let denormalizedBox = CGRect(x: boundingBox.origin.x * colorImageSize.width,
                                    y: boundingBox.origin.y * colorImageSize.height,
                                    width: boundingBox.width * colorImageSize.width,
                                    height: boundingBox.height * colorImageSize.height)
        
        return denormalizedBox
    }
    
    func scaleBoundingBox(boundingBox: CGRect, colorImageSize: CGSize, depthDataSize: CGSize) -> CGRect {
        // 1. Denormalize the bounding box
        let denormalizedBox = denormalizeBoundingBox(boundingBox: boundingBox, colorImageSize: colorImageSize)
        
        // 2. Scale to depth data size
        let scaleX = depthDataSize.width / colorImageSize.width
        let scaleY = depthDataSize.height / colorImageSize.height
        
        let depthBoundingBox = CGRect(x: denormalizedBox.origin.x * scaleX,
                                    y: denormalizedBox.origin.y * scaleY,
                                    width: denormalizedBox.width * scaleX,
                                    height: denormalizedBox.height * scaleY)
        
        return depthBoundingBox
    }
    
    func getPixelBufferSize(pixelBuffer: CVPixelBuffer) -> CGSize {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let size = CGSize(width: width, height: height)
        
        return size
    }

    
    func lidarDistance(boundingBox: CGRect, imagePixelBuffer: CVPixelBuffer, depthPixelBuffer: CVPixelBuffer) -> Float {
        let colorImageSize = self.getPixelBufferSize(pixelBuffer: imagePixelBuffer)
        let depthDataSize = self.getPixelBufferSize(pixelBuffer: depthPixelBuffer)
        
        let depthBoundingBox = scaleBoundingBox(boundingBox: boundingBox, colorImageSize: colorImageSize, depthDataSize: depthDataSize)
        
        // Get the distance to middle of bounding box
        let x = depthBoundingBox.midX
        let y = depthBoundingBox.midY
        
        // Lock the pixel buffer for reading
        CVPixelBufferLockBaseAddress(depthPixelBuffer, CVPixelBufferLockFlags.readOnly)
        
        // Read the depth data at the center of the bounding box
        let pixelBytesPerRow = CVPixelBufferGetBytesPerRow(depthPixelBuffer)
        let pixelBufferBaseAddress = CVPixelBufferGetBaseAddress(depthPixelBuffer)!
        
        let byteOffset = Int(y) * pixelBytesPerRow + Int(x) * 2 // Assuming 16-bit float per pixel
        let depthInMeters = pixelBufferBaseAddress.load(fromByteOffset: byteOffset, as: Float16.self)
        
        
        // Unlock the pixel buffer after reading
        CVPixelBufferUnlockBaseAddress(depthPixelBuffer, CVPixelBufferLockFlags.readOnly)
        
        return Float(depthInMeters)
    }
    
    func depthEstimationDepthMap(imagePixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let image = downsample(pixelBuffer: imagePixelBuffer, toSize: CGSize(width: 304, height: 228))
        let input = FCRNFP16Input(image: image!)
        let prediction = try? depthModel.prediction(input: input)

        
        return prediction?.depthmap.pixelBuffer
    }

    func getObjectClassificationAndDistance(imagePixelBuffer: CVPixelBuffer, depthDataBuffer: CVPixelBuffer) {
        var classifications = [] as [ClassificationData]
            
        // Create a Vision request
        let request = VNCoreMLRequest(model: detectionModel) { request, error in
            if let results = request.results as? [VNRecognizedObjectObservation] {
                for observation in results {
                    let labels = observation.labels
                    
                    // Extract bounding box
                    let boundingBox = observation.boundingBox
                    let boundingBoxDistance = self.lidarDistance(boundingBox: boundingBox, imagePixelBuffer: imagePixelBuffer, depthPixelBuffer: depthDataBuffer)
                    
                    for label in labels {
                        if (label.confidence > 0.5) {
                            let text = "\(label.identifier), distance: \(boundingBoxDistance) m, confidence: \(label.confidence)"
                            print("CLASSIFICATION", text)
                            
                            classifications.append(ClassificationData(label: label.identifier, confidence: label.confidence, distance: boundingBoxDistance, boundingBox: boundingBox))
                        }
                    }
                }
            }
        }
        
        // Use Vision to perform the request on the color image
        let handler = VNImageRequestHandler(cvPixelBuffer: imagePixelBuffer, orientation: .up, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("could not perform request")
        }
        
        delegate?.onClassification(classifications: classifications)
    }
}

// MARK: Output Synchronizer Delegate
extension CameraController: AVCaptureDataOutputSynchronizerDelegate {
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer,
                                didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
        // Retrieve the synchronized depth and sample buffer container objects.
        guard let syncedDepthData = synchronizedDataCollection.synchronizedData(for: depthDataOutput) as? AVCaptureSynchronizedDepthData,
              let syncedVideoData = synchronizedDataCollection.synchronizedData(for: videoDataOutput) as? AVCaptureSynchronizedSampleBufferData else { return }
        
        guard let pixelBuffer = syncedVideoData.sampleBuffer.imageBuffer,
              let cameraCalibrationData = syncedDepthData.depthData.cameraCalibrationData else { return }
        

        var textures: [MTLTexture?]
        if (depthConfiguration.videoFormat == VideoFormat.BGRA_32) {
            textures = [pixelBuffer.texture(withFormat: .bgra8Unorm, planeIndex: 0, addToCache: textureCache)]
        } else {
            textures = [
                pixelBuffer.texture(withFormat: .r8Unorm, planeIndex: 0, addToCache: textureCache),
                pixelBuffer.texture(withFormat: .rg8Unorm, planeIndex: 1, addToCache: textureCache)
            ]
        }
        
        // Package the captured data.
        let data = CameraCapturedData(depth: syncedDepthData.depthData.depthDataMap.texture(withFormat: .r16Float, planeIndex: 0, addToCache: textureCache),
                      colorY: textures,
                      cameraIntrinsics: cameraCalibrationData.intrinsicMatrix,
                      cameraReferenceDimensions: cameraCalibrationData.intrinsicMatrixReferenceDimensions)
        
        // let pixelSize_mm = cameraCalibrationData.pixelSize // Can use this to get relative size of bounding box
//        let dataType = syncedDepthData.depthData.depthDataType // idk if this is useful

        let imagePixelBuffer = syncedVideoData.sampleBuffer.imageBuffer
        var depthPixelBuffer = syncedDepthData.depthData.depthDataMap
        if (depthConfiguration.useEstimation) {
            if let estimation = depthEstimationDepthMap(imagePixelBuffer: imagePixelBuffer!){
                depthPixelBuffer = estimation
            }
        }

        self.getObjectClassificationAndDistance(imagePixelBuffer: imagePixelBuffer!, depthDataBuffer: depthPixelBuffer)

        
        delegate?.onNewData(capturedData: data)
    }
}
