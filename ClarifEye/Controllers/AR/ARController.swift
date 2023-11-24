import UIKit
import SpriteKit
import ARKit
import Vision
import Foundation


protocol ClassificationReceiver: AnyObject {
    func onClassification(classification: ClassificationData)
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
    private var anchorLabels = [UUID: String]()
    var sceneView: ARSKView = ARSKView()
    var classification: ClassificationData?
    var lastClassification: ClassificationData?
    
    var cameraDepthDelegate: CameraInputReceiver?
    var cameraCapturedDataDelegate: CameraCapturedDataReceiver?
    var statusViewManager: StatusViewManager?
    
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
        if (frame.sceneDepth != nil) {
            cameraDepthDelegate?.classify(imagePixelBuffer: frame.capturedImage, depthDataBuffer: frame.sceneDepth!.depthMap)
        }
    }
}


// MARK: - Tap gesture handler & ARSKViewDelegate
extension ARController {
    // When the user taps, add an anchor associated with the current classification result.
    func placeLabelAtLocation(location: CGPoint, label: String) {
        let hitTestResults = sceneView.hitTest(location, types: [.featurePoint, .estimatedHorizontalPlane])
        if let result = hitTestResults.first {
            
            // Add a new anchor at the tap location.
            let anchor = ARAnchor(transform: result.worldTransform)
            sceneView.session.add(anchor: anchor)
            
            // Track anchor ID to associate text with the anchor after ARKit creates a corresponding SKNode.
            anchorLabels[anchor.identifier] = label
            
            // Remove the anchor after 8 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [self] in
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
    func onClassification(classification: ClassificationData) {
        DispatchQueue.main.async {
            let boundingBox = classification.boundingBox
            let point = CGPoint(x: boundingBox.midX, y: boundingBox.midY)
            self.classification = classification
            
            // Use this as a safe guard from placing too many labels down
            if (self.lastClassification == nil || self.lastClassification!.label != classification.label) {
                self.placeLabelAtLocation(location: point, label: classification.label)
                self.lastClassification = self.classification
            }
            
            let message = String(format: "Detected \(classification.label) with %.2f", classification.confidence * 100) + "% confidence" + " \(classification.distance)m away"
            self.statusViewManager?.showMessage(message)
        }
    }
}
