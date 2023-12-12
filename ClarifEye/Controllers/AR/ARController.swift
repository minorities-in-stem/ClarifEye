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
    
    private var anchorLabels = [UUID: String]()
    private var anchorBoundingBoxes = [UUID: CGRect]()
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

        anchorLabels = [UUID: String]()
        
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
    func placeLabelAtLocation(boundingBox: CGRect, distance: Float, label: String, transform: simd_float4x4) {
        let point = CGPoint(x: boundingBox.midX, y: boundingBox.midY)
        let hitTestResults = sceneView.hitTest(point, types: [.featurePoint, .estimatedHorizontalPlane])
        let cgDistance = CGFloat(distance)
        
        if let result = hitTestResults.first {
            // TODO: figure out how to account for when the current camera position is different than when the image was processed
//            let inverseCameraTransform = simd_inverse(transform)
//            let updatedPosition = simd_mul(result.worldTransform, inverseCameraTransform)
            
            // Make sure the anchor is the desired distance away from the camera
            var translation = matrix_identity_float4x4
            translation.columns.3.z = -distance
            
            let anchorTransform = simd_mul(result.worldTransform, translation)
            let anchor = ARAnchor(transform: anchorTransform)
            sceneView.session.add(anchor: anchor)
            
            // Track anchor ID to associate text and bounding boxes with the anchor
            anchorLabels[anchor.identifier] = label
            anchorBoundingBoxes[anchor.identifier] = boundingBox
            
            // Remove the anchor
            DispatchQueue.main.asyncAfter(deadline: .now() + (self.statusViewManager?.displayDuration ?? 3)) { [self] in
                self.anchorLabels.removeValue(forKey: anchor.identifier)
                self.anchorBoundingBoxes.removeValue(forKey: anchor.identifier)
                self.sceneView.session.remove(anchor: anchor)
            }
        }
    }
    
    // When an anchor is added, provide a SpriteKit node for it and set its text to the classification label.
    /// - Tag: UpdateARContent
    func view(_ view: ARSKView, didAdd node: SKNode, for anchor: ARAnchor) {
        // Add Label
        guard let labelText = anchorLabels[anchor.identifier] else {
            fatalError("missing expected associated label for anchor")
        }
        let label = TemplateLabelNode(text: labelText)
        node.addChild(label)
        
        // Add Bounding Box
        guard let boundingBox = anchorBoundingBoxes[anchor.identifier] else {
            fatalError("missing expected associated bounding box for anchor")
        }
//        let target = self.sceneView.bounds.size
//        let boxSize = CGSize(width: boundingBox.width/target.width, height: boundingBox.height/target.height)
//        let boxSize = CGSize(width: boundingBox.width, height: boundingBox.height)
        let boxSize = CGSize(width: 400, height: 400)
        print("BOX SIZE", boxSize)
        let boxNode = SKShapeNode(rectOf: boxSize)
        boxNode.lineWidth = 2
        boxNode.strokeColor = .red
//        boxNode.fillColor = .clear
        boxNode.fillColor = UIColor.red.withAlphaComponent(0.3) // use this for testing
        boxNode.position = boundingBox.origin
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
                let targetSize = self.sceneView.bounds.size
                
                for i in 0..<topObjects.count {
                    let classification = topObjects[i].classification
                    let score = topObjects[i].score
                    
                    if (score >= self.scoreThreshold) {
                        let boundingBox = classification.boundingBox
                    
                        // Scale bounding box to current frame size
                        let boundingBoxForFrame = ClassificationController.scaleToTargetSize(boundingBox: boundingBox, imageSize: imageClassification.imageSize, targetSize: targetSize)
                        
                        self.placeLabelAtLocation(
                            boundingBox: boundingBoxForFrame,
                            distance: classification.distance,
                            label: classification.label,
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
            
            self.classificationsSinceLastOutput.append(imageClassification)
        }
    }
}
