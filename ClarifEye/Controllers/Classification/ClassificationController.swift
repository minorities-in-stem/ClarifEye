import Foundation
import SwiftUI
import Combine
import simd
import AVFoundation
import Vision
import CoreML
import CoreVideo
import CoreImage

protocol CameraDepthReceiver: AnyObject {
    func classifyWithLidar(imagePixelBuffer: CVPixelBuffer, depthDataBuffer: CVPixelBuffer)
    func classifyWithDepthEstimation(imagePixelBuffer: CVPixelBuffer)
}

class ClassificationController: NSObject {
    weak var classificationDelegate: ClassificationReceiver?
    
    var capturedData: CameraCapturedData = CameraCapturedData()
    
    private var currentBuffer: CVPixelBuffer?
    private let videoQueue = DispatchQueue(label: "com.ClarifEye.VideoQueue", qos: .userInteractive)
    private let orientation =  UIDevice.current.orientation
    
    
    // MARK: -Setup for object classification/identification model
    private var _classificationModel: YOLOv3!
    private var classificationModel: YOLOv3! {
        get {
            if let model = _classificationModel { return model }
            _classificationModel = {
                do {
                    let configuration = MLModelConfiguration()
                    return try YOLOv3(configuration: configuration)
                } catch {
                    fatalError("Couldn't create classification model due to: \(error)")
                }
            }()
            return _classificationModel
        }
    }
    
    private lazy var coreMLClassificationModel: VNCoreMLModel = {
        do {
            let model = try VNCoreMLModel(for: classificationModel.model)
            return model
        } catch {
            fatalError("Cannot load model")
        }
    }()
    
    // MARK: -Setup for depth estimation model
    private var _depthModel: FCRNFP16!
    private var depthModel: FCRNFP16! {
        get {
            if let model = _depthModel { return model }
            _depthModel = {
                do {
                    let configuration = MLModelConfiguration()
                    return try FCRNFP16(configuration: configuration)
                } catch {
                    fatalError("Couldn't create depth model due to: \(error)")
                }
            }()
            return _depthModel
        }
    }
}

extension ClassificationController: CameraDepthReceiver {
    func classifyWithLidar(imagePixelBuffer: CVPixelBuffer, depthDataBuffer: CVPixelBuffer) {
        guard currentBuffer == nil else {
            return
        }
        
        self.currentBuffer = imagePixelBuffer
        self.getClassificationAndDistance(imagePixelBuffer: imagePixelBuffer, depthDataBuffer: depthDataBuffer)
    }
    
    func classifyWithDepthEstimation(imagePixelBuffer: CVPixelBuffer) {
        guard currentBuffer == nil else {
            return
        }
        
        self.currentBuffer = imagePixelBuffer
        if let estimation = depthEstimationDepthMap(imagePixelBuffer: imagePixelBuffer){
           let depthPixelBuffer = estimation
            self.getClassificationAndDistance(imagePixelBuffer: imagePixelBuffer, depthDataBuffer: depthPixelBuffer)
       }
    }
    
    
    func getClassificationAndDistance(imagePixelBuffer: CVPixelBuffer, depthDataBuffer: CVPixelBuffer) {
        self.currentBuffer = imagePixelBuffer

        // Create a Vision request
        let request = VNCoreMLRequest(model: self.coreMLClassificationModel) { request, error in
            var classifications = [] as [ClassificationData]
                
            if let results = request.results as? [VNRecognizedObjectObservation] {
                for observation in results {
                    let labels = observation.labels
                    
                    // Extract bounding box
                    let boundingBox = observation.boundingBox
                    let boundingBoxDistance = self.lidarDistance(boundingBox: boundingBox, imagePixelBuffer: imagePixelBuffer, depthPixelBuffer: depthDataBuffer)
                    
                    if let label = labels.first(where: { l in l.confidence > 0.5 }) {
                        let classification = ClassificationData(label: label.identifier, confidence: label.confidence, distance: boundingBoxDistance, boundingBox: boundingBox)
                        
                        // For debugging
                        let text = "\(label.identifier), distance: \(boundingBoxDistance) m, confidence: \(label.confidence)"
                        print("CLASSIFICATION", text)
                        
                        
                        self.classificationDelegate?.onClassification(classification: classification)
                    }
                }
            }
        }
        // Use CPU for Vision processing to ensure that there are adequate GPU resources for rendering.
        request.usesCPUOnly = true
        
        // Use Vision to perform the request on the color image
        let orientation = CGImagePropertyOrientation(self.orientation)
        let handler = VNImageRequestHandler(cvPixelBuffer: imagePixelBuffer, orientation: orientation, options: [:])
        
        videoQueue.async {
            do {
                defer { self.currentBuffer = nil }
                try handler.perform([request])
            } catch {
                print("could not perform request")
            }
        }
    }
}


// MARK: -Helper Methods
extension ClassificationController {
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
        let prediction = try? self.depthModel.prediction(input: input)

        
        return prediction?.depthmap.pixelBuffer
    }
}
