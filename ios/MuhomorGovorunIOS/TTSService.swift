import AVFoundation
import Foundation
import NaturalLanguage
import Observation

@Observable
final class TTSService: NSObject {
    var status = "Готов"
    private let localSynth = AVSpeechSynthesizer()

    func speakLocal(text rawText: String, config: AppConfig) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        stop()
        do {
            try activatePlaybackSession()
        } catch {
            status = "Ошибка аудио: \(error.localizedDescription)"
            return
        }
        status = "Озвучиваю локально"
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.voice(for: text, config: config)
        utterance.rate = Float(config.rate)
        utterance.pitchMultiplier = Float(config.pitch)
        localSynth.speak(utterance)
    }

    func stop() {
        localSynth.stopSpeaking(at: .immediate)
        status = "Остановлено"
    }

    private func activatePlaybackSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true)
    }

    private static func voice(for text: String, config: AppConfig) -> AVSpeechSynthesisVoice? {
        let languageCode = detectedLanguageCode(from: text)
        return voice(languageCode: languageCode)
            ?? AVSpeechSynthesisVoice(language: config.voiceLanguage)
            ?? AVSpeechSynthesisVoice(language: "ru-RU")
    }

    private static func detectedLanguageCode(from text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        if let language = recognizer.dominantLanguage, language.rawValue != "und" {
            return language.rawValue
        }

        if text.range(of: "\\p{Cyrillic}", options: .regularExpression) != nil {
            return "ru"
        }

        if text.range(of: "\\p{Latin}", options: .regularExpression) != nil {
            return "en"
        }

        return "ru"
    }

    private static func voice(languageCode: String) -> AVSpeechSynthesisVoice? {
        let normalizedCode = languageCode.lowercased()
        return AVSpeechSynthesisVoice.speechVoices().first { voice in
            let language = voice.language.lowercased()
            return language == normalizedCode || language.hasPrefix("\(normalizedCode)-")
        }
    }
}
