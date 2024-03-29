import UIKit
import SpriteKit
import ARKit
import Vision
import Foundation

protocol ClassificationReceiver: AnyObject {
    func onClassification(imageClassification: ImageClassification)
}

// Convert device orientation to image orientation for use by Vision analysis.
extension CGImagePropertyOrientation {
    init(_ deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
            case .portraitUpsideDown: self = .left
            case .landscapeLeft: self = .up
            case .landscapeRight: self = .down
            default: self = .right
        }
    }
}


class ARController: UIViewController, UIGestureRecognizerDelegate, ARSKViewDelegate, ARSessionDelegate {
    // Minimum severity score to display feedback
    // FOR NOW, set this to be low so we can test UI interactions
    // TODO: modify this threshold to be more reasonable
    var scoreThreshold: Float = 3
    var maxNumOfObjectsToDisplay: Int = 3 // Maximum number of observations per frame to display
    private var missingCountThresholdForDeletion: Int = 5 // How many counts before an object is deleted
    
    private var smoothingFactor: Float = 0.2 // For depth smoothing
    
    private var anchorToClassification = [UUID: ClassificationData]()
    var sceneView: ARSKView = ARSKView()
    
    var depthPerClassificationSinceLastOutput: Dictionary<String, [Float]> = [:]
    var lastTransformPerClassificationSinceLastOutput: Dictionary<String, simd_float4x4> = [:]
    var missingCounterPerClassificationSinceLastOutput: Dictionary<String, Int>  = [:]
    
    var classificationController: ClassificationController = ClassificationController()
    var cameraCapturedDataDelegate: CameraCapturedDataReceiver?
    var statusViewManager: StatusViewManager?
    var ttsManager: TTSManager?
    var settings: Settings?
    var modelReady: Bool = false {
        didSet {
            self.cameraCapturedDataDelegate?.setInitialized(self.modelReady)
        }
    }
    var streamAvailable: Bool = false {
        didSet {
            self.cameraCapturedDataDelegate?.setStreamAvailable(self.streamAvailable)
        }
    }
    
    private var shouldClassify: Bool = true
    private var classificationTimer: Timer?
    
    private let meterToFootRatio: Float = 3.28084
    
    deinit {
        removeClassificationTimer()
    }
    
    func addClassificationTimer() {
        self.classificationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.shouldClassify.toggle()
        }
    }
    
    func removeClassificationTimer() {
        classificationTimer?.invalidate()
    }
    
    func start() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
        sceneView.session.run(configuration)
        addClassificationTimer()
    }
    
    func pause() {
        sceneView.session.pause()
        removeClassificationTimer()
    }
    
    
    // MARK: - View controller lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.frame = self.view.bounds
        self.view.addSubview(sceneView)
        
        // Configure and present the SpriteKit scene that draws overlay content.
        let overlayScene = SKScene()
        overlayScene.scaleMode = .aspectFill
        sceneView.delegate = self
        sceneView.presentScene(overlayScene)
        sceneView.session.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.pause()
    }
    
    
    // MARK: - AR Session Handling
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        if (self.modelReady != classificationController.modelReady) {
            self.modelReady = classificationController.modelReady
        }

        if (!self.modelReady) {
            return
        }
        
        var message = camera.trackingState.presentationString
        if let recommendation = camera.trackingState.recommendation {
            message.append(": \(recommendation)")
        }
        
        self.ttsManager?.stopSpeaking()
        if (camera.trackingState == .normal) {
            print("Tracking state normal")
            startStream()
        } else {
            print("Tracking state: ", camera.trackingState)
            pauseStream()
            statusViewManager?.scheduleMessage(message, inSeconds: 0, messageType: .trackingStateEscalation, autoHide: false, isError: true)
            if (self.settings != nil && self.settings!.audioOutput) {
                ttsManager?.speak(message)
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        
        // Filter out optional error messages.
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        DispatchQueue.main.async {
            self.displayErrorMessage(title: "The AR session failed.", message: errorMessage)
        }
    }
    
    private func setOverlaysHidden(_ shouldHide: Bool) {
        sceneView.scene!.children.forEach { node in
            if shouldHide {
                // Hide overlay content immediately during relocalization.
                node.alpha = 0
            } else {
                // Fade overlay content in after relocalization succeeds.
                node.run(.fadeIn(withDuration: 0.5))
            }
        }
    }

     func restartSession() {
         statusViewManager?.cancelAllScheduledMessages()
         statusViewManager?.showMessage("Restarting Session", isError: true)

         anchorToClassification = [UUID: ClassificationData]()
        
         let configuration = ARWorldTrackingConfiguration()
         configuration.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
         sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
         
         self.removeClassificationTimer()
         self.addClassificationTimer()
         
         self.resetClassificationTracking()
    }
    
    // MARK: - Error handling
    
    private func displayErrorMessage(title: String, message: String) {
        // Present an alert informing about the error that has occurred.
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
            alertController.dismiss(animated: true, completion: nil)
            self.restartSession()
        }
        alertController.addAction(restartAction)
        present(alertController, animated: true, completion: nil)
    }
}

// MARK: - ARSessionDelegate
extension ARController {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if (frame.smoothedSceneDepth != nil && self.shouldClassify) {
            let transform = frame.camera.transform
            self.classificationController.classify(imagePixelBuffer: frame.capturedImage, depthDataBuffer: frame.smoothedSceneDepth!.depthMap, transform: transform)
            self.shouldClassify = false
        }
    }
}


// MARK: - Tap gesture handler & ARSKViewDelegate
extension ARController {
    func placeClassificationLabel(classification: ClassificationData, originalImageSize: CGSize, transform: simd_float4x4) {
        DispatchQueue.main.async {
            // Scale bounding box to current frame size
            let boundingBox = classification.boundingBox
            let point = CGPoint(x: boundingBox.midX, y: 1-boundingBox.midY)
            if let anchor = self.getAnchorForLocation(location: point, distance: classification.distance, label: classification.label, transform: transform) {
                // Track anchor ID to associate text and bounding boxes with the anchor
                self.anchorToClassification[anchor.identifier] = classification
                self.sceneView.session.add(anchor: anchor)
                
                // Remove the anchor
                DispatchQueue.main.asyncAfter(deadline: .now() + (self.statusViewManager?.displayDuration ?? 3)) { [self] in
                    self.anchorToClassification.removeValue(forKey: anchor.identifier)
                    self.sceneView.session.remove(anchor: anchor)
                }
            }
        }
        
    }
    
    func getAnchorForLocation(location: CGPoint, distance: Float?, label: String, transform: simd_float4x4) -> ARAnchor? {
        // If no distance, don't place a label; the distance is treated as unknown
        if (distance == nil) {
            print("No distance found")
            return nil
        }

        guard let query = self.sceneView.session.currentFrame?.raycastQuery(from: location, allowing: .estimatedPlane, alignment: .any)
        else {
            print("Could not create query")
            return nil
        }
        
        let result = self.sceneView.session.raycast(query).first
        
        if (result == nil) {
            print("Raycast did not return any results for location \(location)")
            
            var translation = matrix_identity_float4x4
            translation.columns.3.z = -distance!

            let anchorTransform = simd_mul(transform, translation)
            let anchor = ARAnchor(transform: anchorTransform)
            return anchor
        }
        
        
        var anchorTransform = result!.worldTransform
        anchorTransform.columns.3.z = -distance!
        let anchor = ARAnchor(transform: anchorTransform)
        
        return anchor
    }
    
    // When an anchor is added, provide a SpriteKit node for it and set its text to the classification label.
    /// - Tag: UpdateARContent
    func view(_ view: ARSKView, didAdd node: SKNode, for anchor: ARAnchor) {
        guard let classification = anchorToClassification[anchor.identifier] else {
            fatalError("missing expected classification for anchor")
        }
        
        // Add Label
        let labelText = classification.label
        let label = TemplateLabelNode(text: labelText)
        node.addChild(label)
        
        // Add Bounding Box
//        guard let frame = self.sceneView.session.currentFrame else { return }
//        let viewPortSize = self.sceneView.bounds.size
//        let interfaceOrientation = self.sceneView.window!.windowScene!.interfaceOrientation
//        
//        let boundingBox = classification.boundingBox
//        
//        let scale = max(viewPortSize.width, viewPortSize.height)
//        let boxNode = BoundingBoxNode(boundingBox, CGSize(width: scale, height: scale))
//        node.addChild(boxNode)
    }
}

// MARK: - Handle classification display
extension ARController: ClassificationReceiver {
    func resetClassificationTracking() {
        self.depthPerClassificationSinceLastOutput = [:]
        self.lastTransformPerClassificationSinceLastOutput = [:]
        self.missingCounterPerClassificationSinceLastOutput = [:]
    }
    
    func startStream() {
        DispatchQueue.main.async {
            self.streamAvailable = true
            self.addClassificationTimer()
            // Unhide content after successful relocalization.
            self.setOverlaysHidden(false)
        }
    }
    
    func pauseStream() {
        DispatchQueue.main.async {
            self.streamAvailable = false
            self.removeClassificationTimer()
            self.setOverlaysHidden(true)
        }
    }
    
    func onClassification(imageClassification: ImageClassification) {
        DispatchQueue.main.async {
            let displayOutput = self.statusViewManager != nil && !self.statusViewManager!.showText
            if (displayOutput) {
                var scoredClassifications: [ScoredClassification] = []
                for classification in imageClassification.classifications.values {
                    // Only consider objects that are not marked as "other"
                    if (classification.label != ObstacleLabel.OTHER.rawValue) {
                        // ASSUME OBJECTS ARE STATIC FOR NOW
                        let obstacleLabel = ObstacleLabel.fromString(classification.label)
                        let score = CalculateScore(label: obstacleLabel, depth: classification.distance, speed: 0)
                        scoredClassifications.append(ScoredClassification(classification: classification, score: score))
                    }
                }
                
                let threshold = min(self.maxNumOfObjectsToDisplay, scoredClassifications.count)
                let topObjects = (scoredClassifications.sorted { $0.score > $1.score })[..<threshold]
                
                for i in 0..<topObjects.count {
                    let classification = topObjects[i].classification
                    let score = topObjects[i].score
                    
                    // Perform depth smoothing based on all the times it's appeared in previous time steps
                    let previousDepths = self.depthPerClassificationSinceLastOutput[classification.label]
                    let hasPreviousDepths = previousDepths == nil || previousDepths!.count == 0
                    let smoothedDepth = hasPreviousDepths ? classification.distance : performSmoothing(data: previousDepths!, alpha: self.smoothingFactor)!.last
                    let smoothedClassification = ClassificationData(
                        label: classification.label,
                        confidence: classification.confidence,
                        distance: smoothedDepth,
                        boundingBox: classification.boundingBox
                    )
                    
                    
                    if (score >= self.scoreThreshold) {
                        self.placeClassificationLabel(
                            classification: smoothedClassification,
                            originalImageSize: imageClassification.imageSize,
                            transform: imageClassification.transform
                        )
    
                        // Display the message for the object at the first index; which is the object with the highest hazard score
                        if (i == 0) {
                            var reportedDepth: String = ""
                            if (smoothedDepth == nil) {
                                reportedDepth = "an unknown distance"
                            } else if (self.settings != nil && self.settings!.measurementSystem == .Imperial) {
                                reportedDepth = String(format: "%.2f ft", smoothedDepth! * self.meterToFootRatio)
                            } else {
                                reportedDepth = String(format: "%.2f m", smoothedDepth!)
                            }
                            
                            
                            // MARK: - Grab the position relative to the user
                            let boundingBox = classification.boundingBox
                            let label = cleanLabel(classification.label)
                            var relativePosition = ""
                            if (boundingBox.maxX < 0.5) { // Left
                                relativePosition = "slight left"
                            } else if (boundingBox.minX > 0.5) { // Right
                                relativePosition = "slight right"
                            } else { // Center
                                relativePosition = "in front"
                            }
                            
                            //- MARK: feedback to user
                            // let reportedConfidence = String(format: "%.2f % confidence", classification.confidence * 100)
                            let message = "\(label) \(reportedDepth) \(relativePosition)"
                            print(message)
                            
                            self.statusViewManager?.showMessage(message, autoHide: true)
                            if (self.settings != nil && self.settings!.audioOutput) {
                                self.ttsManager?.speak(message)
                            }
                        }
                    }
                }
                
                self.resetClassificationTracking()
            }
        
            
            // Add current labels
            for classification in imageClassification.classifications.values {
                if (!self.depthPerClassificationSinceLastOutput.keys.contains(classification.label)) {
                    self.depthPerClassificationSinceLastOutput[classification.label] = []
                }
                
                if (classification.distance != nil) {
                    self.depthPerClassificationSinceLastOutput[classification.label]!.append(classification.distance!)
                }
                
                // This marks the last known relative position for a given label
                self.lastTransformPerClassificationSinceLastOutput[classification.label] = imageClassification.transform
            }
            
            // Compare previous labels with current labels and delete if necessary
            for existingClassificationLabel in self.depthPerClassificationSinceLastOutput.keys {
                // If the object was in a previous frame but is no longer in the frame
                if (!imageClassification.classifications.keys.contains(existingClassificationLabel)) {
                    if (!self.missingCounterPerClassificationSinceLastOutput.keys.contains(existingClassificationLabel)) {
                        self.missingCounterPerClassificationSinceLastOutput[existingClassificationLabel] = 0
                    }
                    self.missingCounterPerClassificationSinceLastOutput[existingClassificationLabel]! += 1
                    
                    if (self.missingCounterPerClassificationSinceLastOutput[existingClassificationLabel] == self.missingCountThresholdForDeletion) {
                        self.depthPerClassificationSinceLastOutput.removeValue(forKey: existingClassificationLabel)
                    }
                }
            }
        }
    }
}
