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
    var sceneView: ARSKView = ARSKView()
    var classificationsSinceLastOutput: [ImageClassification] = []
    
    var classificationController: ClassificationController = ClassificationController()
    var cameraCapturedDataDelegate: CameraCapturedDataReceiver?
    var statusViewManager: StatusViewManager?
    
    var displayingOutput: Bool = false
    
    func start() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
        sceneView.session.run(configuration)
    }
    
    func pause() {
        sceneView.session.pause()
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
        if (frame.smoothedSceneDepth != nil) {
            DispatchQueue.main.async {
                let transform = frame.camera.transform
                self.classificationController.classify(imagePixelBuffer: frame.capturedImage, depthDataBuffer: frame.smoothedSceneDepth!.depthMap, transform: transform)
                
            }
        }
    }
}


// MARK: - Tap gesture handler & ARSKViewDelegate
extension ARController {
    func placeLabelAtLocation(location: CGPoint, distance: Float, label: String, transform: simd_float4x4) {
        let hitTestResults = sceneView.hitTest(location, types: [.featurePoint, .estimatedHorizontalPlane])
        let cgDistance = CGFloat(distance)
        
        if let result = hitTestResults.first(where: { res in res.distance >= cgDistance }) ?? hitTestResults.first {
            let updatedPosition = simd_mul(result.worldTransform, transform)
            let anchor = ARAnchor(transform: updatedPosition)
            sceneView.session.add(anchor: anchor)
            
            // Track anchor ID to associate text with the anchor after ARKit creates a corresponding SKNode.
            anchorLabels[anchor.identifier] = label
            
            // Remove the anchor
            DispatchQueue.main.asyncAfter(deadline: .now() + (self.statusViewManager?.displayDuration ?? 3)) { [self] in
                self.sceneView.session.remove(anchor: anchor)
            }
        }
    }
    
    // When an anchor is added, provide a SpriteKit node for it and set its text to the classification label.
    /// - Tag: UpdateARContent
    func view(_ view: ARSKView, didAdd node: SKNode, for anchor: ARAnchor) {
        guard let labelText = anchorLabels[anchor.identifier] else {
            fatalError("missing expected associated label for anchor")
        }
        let label = TemplateLabelNode(text: labelText)
        node.addChild(label)
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
                let frameSize = self.sceneView.frame.size
                
                for i in 0..<topObjects.count {
                    let classification = topObjects[i].classification
                    let score = topObjects[i].score
                    
                    if (score >= self.scoreThreshold) {
                        let boundingBox = classification.boundingBox
                    
                        // Scale bounding box to current frame size
                        let boundingBoxForFrame = ClassificationController.scaleBoundingBox(boundingBox: boundingBox, imageSize: imageClassification.imageSize, targetSize: frameSize)
                        
                        let boundingBoxMiddle = CGPoint(x: boundingBoxForFrame.midX, y: boundingBoxForFrame.midY)
                        self.placeLabelAtLocation(
                            location: boundingBoxMiddle,
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
