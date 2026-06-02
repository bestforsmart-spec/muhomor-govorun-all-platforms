import AVFoundation
import Foundation
import Observation

@Observable
final class TTSService: NSObject {
    var status = "Готов"
    private let localSynth = AVSpeechSynthesizer()

    func speakLocal(text rawText: String, config: AppConfig) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        stop()
        status = "Озвучиваю локально"
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: config.voiceLanguage)
        utterance.rate = Float(config.rate)
        utterance.pitchMultiplier = Float(config.pitch)
        localSynth.speak(utterance)
    }

    func stop() {
        localSynth.stopSpeaking(at: .immediate)
        status = "Остановлено"
    }
}
