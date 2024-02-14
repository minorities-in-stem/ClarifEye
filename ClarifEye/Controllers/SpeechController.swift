import Foundation
import AVFoundation


class SpeechController: NSObject, AVSpeechSynthesizerDelegate {
    var voice: AVSpeechSynthesisVoice
    var synth: AVSpeechSynthesizer
    
    init(accent: String = "en-GB") {
        self.voice = AVSpeechSynthesisVoice(language: "en-GB")!
        self.synth = AVSpeechSynthesizer()
    }
//    var utterance: AVSpeechUtterance?
    
    func playMessage(_ text: String) {
        print("foo")
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = self.voice
        self.synth.speak(utterance)
    }
}
