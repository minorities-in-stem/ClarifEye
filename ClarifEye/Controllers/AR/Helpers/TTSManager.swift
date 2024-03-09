import AVFoundation

class TTSManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    var synthesizer: AVSpeechSynthesizer = AVSpeechSynthesizer()
    
    @Published var utteranceRate: Float = 0.1
    @Published var language: String = "en-US"
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    
    func speak(_ text: String) {
        print("Speaking: ", text)
        let utterance = AVSpeechUtterance(string: text)
        
//        utterance.voice = AVSpeechSynthesisVoice(language: self.language)
        utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.speech.synthesis.voice.Fred")
        utterance.rate = self.utteranceRate
        
        synthesizer.speak(utterance)
    }
}
