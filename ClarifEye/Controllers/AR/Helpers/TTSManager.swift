import AVFoundation

class TTSManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    var synthesizer: AVSpeechSynthesizer = AVSpeechSynthesizer()
    
    @Published var utteranceRate: Float = 0.5
    
    override init() {
        super.init()
        synthesizer.delegate = self
//        print(AVSpeechSynthesisVoice.speechVoices())
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        }
        catch {
            print(error)
        }
    }
    
    
    func speak(_ text: String) {
//        print("Speaking: ", text)
        let utterance = AVSpeechUtterance(string: text)
        
        utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.compact.en-US.Samantha")
        utterance.rate = self.utteranceRate
        
        synthesizer.speak(utterance)
    }
}
