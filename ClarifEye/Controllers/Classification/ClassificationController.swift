import Foundation
import SwiftUI
import Combine
import simd
import AVFoundation
import Vision
import CoreML
import CoreVideo
import CoreImage

class ClassificationController: NSObject {
    weak var classificationDelegate: ClassificationReceiver?
    var modelReady: Bool = false 
    
    private var currentBuffer: CVPixelBuffer?
    private let dispatchQueue = DispatchQueue.global(qos: .background)
    private let orientation =  UIDevice.current.orientation
    
    
    // MARK: -Setup for object classification/identification model
    private var classificationModel: best!
    private var coreMLClassificationModel: VNCoreMLModel
    
    override init() {
        do {
            let configuration = MLModelConfiguration()
            self.classificationModel = try best(configuration: configuration)
            
            let model = try VNCoreMLModel(for: self.classificationModel.model)
            self.coreMLClassificationModel = model
            modelReady = true
        } catch {
            fatalError("Cannot load model. \(error)")
        }
        
        super.init()
    }
}

extension ClassificationController {
    func classify(imagePixelBuffer: CVPixelBuffer, depthDataBuffer: CVPixelBuffer, transform: simd_float4x4) {
        guard self.currentBuffer == nil else {
            return
        }
        
        let image = imagePixelBuffer
        self.getClassificationAndDistance(imagePixelBuffer: image, depthDataBuffer: depthDataBuffer, transform: transform)
    }
    
    
    func getClassificationAndDistance(imagePixelBuffer: CVPixelBuffer, depthDataBuffer: CVPixelBuffer, transform: simd_float4x4) {
        dispatchQueue.async {
            self.currentBuffer = imagePixelBuffer
            
            let request = VNCoreMLRequest(model: self.coreMLClassificationModel) { request, error in
                
                if let results = request.results as? [VNRecognizedObjectObservation] {
                    var classifications: Dictionary<String, ClassificationData> = [:]
                    for observation in results {
                        let labels = observation.labels
                        
                        // Extract bounding box
                        let boundingBox = observation.boundingBox
                        let boundingBoxDistance = self.getDistanceFromDepthMap(boundingBox: boundingBox, depthPixelBuffer: depthDataBuffer)
                        
                        // TODO: rethink; do we want to take the label with the highest confidence or only one with a confidence higher than 0.5
                        // Do we need to take confidence of prediction into consideration before reporting to the user? Ex. a closer object with low confidence/unknown vs. slightly further object with more confidence
                        if let label = labels.first(where: { l in l.confidence > 0.5 }) {
                            let obstacleLabel = ObstacleLabel.fromString(label.identifier)
                            let cleanedLabel = cleanLabel(obstacleLabel.rawValue)
                            let classification = ClassificationData(
                                label: cleanedLabel,
                                confidence: label.confidence,
                                distance: boundingBoxDistance,
                                boundingBox: boundingBox
                            )
                            
                            // Assume that there is only one type of each object per image/frame
                            // Take the one with the closest distance
                            if (!classifications.keys.contains(cleanedLabel) ||  boundingBoxDistance < classifications[cleanedLabel]!.distance!) {
                                classifications[cleanedLabel] = classification
                            }
                        }
                        
                    }
                    let imageClassification = ImageClassification(
                        imageSize: self.getPixelBufferSize(imagePixelBuffer),
                        classifications: classifications,
                        transform: transform
                    )
                    
                    self.classificationDelegate?.onClassification(imageClassification: imageClassification)
                }
            }
            // Use CPU for Vision processing to ensure that there are adequate GPU resources for rendering.
            request.usesCPUOnly = true

            let orientation = CGImagePropertyOrientation(self.orientation)
            let handler = VNImageRequestHandler(cvPixelBuffer: imagePixelBuffer, orientation: orientation, options: [:])
            
            do {
                defer { self.currentBuffer = nil }
                try handler.perform([request])
            } catch {
                print("could not perform request")
            }
        }
    }
}


// MARK: -Helper MethodsonModelReady
extension ClassificationController {
    static func scaleToTargetSize(boundingBox: CGRect, targetSize: CGSize) -> CGRect {
        let scaleX = targetSize.width
        let scaleY = targetSize.height
        
        let depthBoundingBox = CGRect(x: boundingBox.origin.x * scaleX,
                                      y: boundingBox.origin.y * scaleY,
                                      width: boundingBox.width * scaleX,
                                      height: boundingBox.height * scaleY)
        
        return depthBoundingBox
    }
    
    func getPixelBufferSize(_ pixelBuffer: CVPixelBuffer) -> CGSize {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let size = CGSize(width: width, height: height)
        
        return size
    }

    
    func getDistanceFromDepthMap(boundingBox: CGRect, depthPixelBuffer: CVPixelBuffer) -> Float {
        let depthDataSize = self.getPixelBufferSize(depthPixelBuffer)
        let depthBoundingBox = ClassificationController.scaleToTargetSize(boundingBox: boundingBox, targetSize: depthDataSize)
        
        // Lock the pixel buffer for reading
        CVPixelBufferLockBaseAddress(depthPixelBuffer, CVPixelBufferLockFlags.readOnly)
        
        // Read the depth data at the center of the bounding box
        let pixelBytesPerRow = CVPixelBufferGetBytesPerRow(depthPixelBuffer)
        let pixelBufferBaseAddress = CVPixelBufferGetBaseAddress(depthPixelBuffer)!
        
        var shortestDistance: Float = Float.greatestFiniteMagnitude // Initialize with the maximum possible value
        
        // Iterate over each pixel within the bounding box
        for y in Int(depthBoundingBox.minY)..<Int(depthBoundingBox.maxY) {
            for x in Int(depthBoundingBox.minX)..<Int(depthBoundingBox.maxX) {
                let byteOffset = y * pixelBytesPerRow + x * 4 // Assuming depth data is Float32b
                let depthInMeters = pixelBufferBaseAddress.load(fromByteOffset: byteOffset, as: Float32.self)
                if (depthInMeters < shortestDistance) {
                    shortestDistance = depthInMeters
                }
            }
        }
        
        // Unlock the pixel buffer after reading
        CVPixelBufferUnlockBaseAddress(depthPixelBuffer, CVPixelBufferLockFlags.readOnly)
        
        return Float(shortestDistance)
    }
}
