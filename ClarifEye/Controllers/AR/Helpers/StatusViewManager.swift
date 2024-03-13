import Foundation
import ARKit

class StatusViewManager: ObservableObject {
    enum MessageType {
        case trackingStateEscalation
        case planeEstimation
        case contentPlacement
        case focusSquare
        
        static var all: [MessageType] = [
            .trackingStateEscalation,
            .planeEstimation,
            .contentPlacement,
            .focusSquare
        ]
    }

    @Published var message: String! = ""
    @Published var showText: Bool = false {
        didSet {
            self.delegate?.onShowText(showText: showText)
        }
    }
    
    var delegate: StatusViewManagerDelegate?
    var displayDuration: TimeInterval = 3 // THIS IS THE LENGTH OF THE FEEDBACK CYCLE
    private var messageHideTimer: Timer?

    private var timers: [MessageType: Timer] = [:]
    
    // MARK: - Message Handling
    func showMessage(_ text: String, autoHide: Bool = true, isError: Bool = false) {
        DispatchQueue.main.async {
            // Cancel any previous hide timer.
            self.messageHideTimer?.invalidate()
            
            self.message = text
            self.delegate?.onMessage(self.message, isError: isError)
            
            // Make sure status is showing.
            self.setMessageHidden(false)
            
            if autoHide {
                self.messageHideTimer = Timer.scheduledTimer(withTimeInterval: self.displayDuration, repeats: false, block: { [weak self] _ in
                    self?.setMessageHidden(true)
                })
            }
        }
    }
    
    func scheduleMessage(_ text: String, inSeconds seconds: TimeInterval, messageType: MessageType, autoHide: Bool = false, isError: Bool = false) {
        cancelScheduledMessage(for: messageType)
        
        let timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false, block: { [weak self] timer in
            self?.showMessage(text, isError: isError)
            timer.invalidate()
        })
        
        timers[messageType] = timer
    }
    
    func cancelScheduledMessage(`for` messageType: MessageType) {
        timers[messageType]?.invalidate()
        timers[messageType] = nil
    }
    
    func cancelAllScheduledMessages() {
        for messageType in MessageType.all {
            cancelScheduledMessage(for: messageType)
        }
    }
    
    
    // MARK: - Panel Visibility
    private func setMessageHidden(_ hide: Bool) {
        self.showText = !hide
    }
}

