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
    var scoreThreshold: Float = 3
    var maxNumOfObjectsToDisplay: Int = 3 // Maximum number of observations per frame to display
    
    private var anchorToClassification = [UUID: ClassificationData]()
    var sceneView: ARSKView = ARSKView()
    var classificationsSinceLastOutput: [ImageClassification] = []
    
    var classificationController: ClassificationController = ClassificationController()
    var cameraCapturedDataDelegate: CameraCapturedDataReceiver?
    var statusViewManager: StatusViewManager?
    
    private var shouldClassify: Bool = true
    private var classificationTimer: Timer?
    
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
        statusViewManager?.showTrackingQualityInfo(for: camera.trackingState, autoHide: true)
        
        switch camera.trackingState {
        case .notAvailable, .limited:
            statusViewManager?.escalateFeedback(for: camera.trackingState, inSeconds: 3.0)
        case .normal:
            statusViewManager?.cancelScheduledMessage(for: .trackingStateEscalation)
            // Unhide content after successful relocalization.
            setOverlaysHidden(false)
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
    
    func sessionWasInterrupted(_ session: ARSession) {
        setOverlaysHidden(true)
    }
    
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        /*
         Allow the session to attempt to resume after an interruption.
         This process may not succeed, so the app must be prepared
         to reset the session if the relocalizing status continues
         for a long time -- see `escalateFeedback` in `StatusViewController`.
         */
        return true
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
        statusViewManager?.showMessage("RESTARTING SESSION")

        anchorToClassification = [UUID: ClassificationData]()
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
         
        removeClassificationTimer()
        addClassificationTimer()
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
            DispatchQueue.main.async {
                let transform = frame.camera.transform
                self.classificationController.classify(imagePixelBuffer: frame.capturedImage, depthDataBuffer: frame.smoothedSceneDepth!.depthMap, transform: transform)
                self.shouldClassify = false
            }
        }
    }
}


// MARK: - Tap gesture handler & ARSKViewDelegate
extension ARController {
    func placeClassificationLabel(classification: ClassificationData, originalImageSize: CGSize, transform: simd_float4x4) {
        // Scale bounding box to current frame size
        let targetSize = self.sceneView.bounds.size
        let boundingBox = ClassificationController.scaleToTargetSize(boundingBox: classification.boundingBox, imageSize: originalImageSize, targetSize: targetSize)
        let point = CGPoint(x: boundingBox.midX, y: boundingBox.midY)
                            
        // TESTING
//        let flipped = CGRect(
//            x: boundingBox.minX,
//            y: 1 - boundingBox.maxY,
//            width: boundingBox.width,
//            height: boundingBox.height
//        )
//        let point = CGPoint(x: flipped.midX, y: flipped.midY)
                            
        if let anchor = self.getAnchorForLocation(location: point, distance: classification.distance, label: classification.label, transform: transform) {
            // Track anchor ID to associate text and bounding boxes with the anchor
            anchorToClassification[anchor.identifier] = classification
            sceneView.session.add(anchor: anchor)
            
            // Remove the anchor
            DispatchQueue.main.asyncAfter(deadline: .now() + (self.statusViewManager?.displayDuration ?? 3)) { [self] in
                self.anchorToClassification.removeValue(forKey: anchor.identifier)
                self.sceneView.session.remove(anchor: anchor)
            }
        }
    }
    
    func getAnchorForLocation(location: CGPoint, distance: Float, label: String, transform: simd_float4x4) -> ARAnchor? {
        var translation = matrix_identity_float4x4
        translation.columns.3.z = -distance
        let anchorTransform = simd_mul(transform, translation)
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
        guard let frame = self.sceneView.session.currentFrame else { return }
        let viewPortSize = self.sceneView.bounds.size
        let interfaceOrientation = self.sceneView.window!.windowScene!.interfaceOrientation
        
        let displayTransform = frame.displayTransform(for: interfaceOrientation, viewportSize: viewPortSize)
        let toViewPortTransform = CGAffineTransform(scaleX: viewPortSize.width, y: viewPortSize.height)
        
        let boundingBox = classification.boundingBox.applying(displayTransform).applying(toViewPortTransform)
        
        let scale = max(viewPortSize.width, viewPortSize.height)
        let boxNode = BoundingBoxNode(boundingBox, CGSize(width: scale, height: scale))
        node.addChild(boxNode)
    }
}

// MARK: - Handle classification display
extension ARController: ClassificationReceiver {
    func onClassification(imageClassification: ImageClassification) {
        DispatchQueue.main.async {
            if (self.statusViewManager != nil && !self.statusViewManager!.showText) {
                var scoredClassifications: [ScoredClassification] = []
                for classification in imageClassification.classifications {
                    // ASSUME OBJECTS ARE STATIC FOR NOW
                    let obstacleLabel = ObstacleLabel.fromString(classification.label)
                    let score = CalculateScore(label: obstacleLabel, depth: classification.distance, speed: 0)
                    scoredClassifications.append(ScoredClassification(classification: classification, score: score))
                }
                
                let threshold = min(self.maxNumOfObjectsToDisplay, scoredClassifications.count)
                let topObjects = (scoredClassifications.sorted { $0.score > $1.score })[..<threshold]
                
                for i in 0..<topObjects.count {
                    let classification = topObjects[i].classification
                    let score = topObjects[i].score
                    
                    if (score >= self.scoreThreshold) {
                        self.placeClassificationLabel(
                            classification: classification,
                            originalImageSize: imageClassification.imageSize,
                            transform: imageClassification.transform
                        )
    
                        // Display the message for the object at the first index; which is the object with the highest hazard score
                        if (i == 0) {
                            let message = String(format: "Detected \(classification.label) with %.2f", classification.confidence * 100) + "% confidence" + " \(classification.distance)m away"
                            self.statusViewManager?.showMessage(message, autoHide: true)
                        }
                    }
                }
                
                // Reset the cycle
                self.classificationsSinceLastOutput = []
            }
            
            for classification in imageClassification.classifications {
                
            }
            self.classificationsSinceLastOutput.append(imageClassification)
        }
    }
}
