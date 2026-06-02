import AVFoundation
import Foundation
import Observation

@Observable
final class TTSService: NSObject, AVAudioPlayerDelegate {
    var status = "Готов"
    private let localSynth = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?

    func speak(text rawText: String, config: AppConfig) async {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        stop()

        do {
            switch config.backend {
            case .localFast:
                speakLocal(text)
            case .salute:
                let data = try await synthesizeSalute(text: text, config: config)
                try play(data: data, extension: "wav")
            case .elevenLabs:
                let data = try await synthesizeElevenLabs(text: text, config: config)
                try play(data: data, extension: "mp3")
            }
        } catch {
            status = "Ошибка: \(error.localizedDescription)"
        }
    }

    func stop() {
        localSynth.stopSpeaking(at: .immediate)
        player?.stop()
        player = nil
        status = "Остановлено"
    }

    private func speakLocal(_ text: String) {
        status = "Озвучиваю локально"
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ru-RU")
        utterance.rate = 0.49
        localSynth.speak(utterance)
    }

    private func synthesizeSalute(text: String, config: AppConfig) async throws -> Data {
        guard !config.saluteAuthKey.isEmpty else { throw TTSServiceError.missingKey("SaluteSpeech") }
        status = "Получаю токен SaluteSpeech"

        var tokenRequest = URLRequest(url: URL(string: "https://ngw.devices.sberbank.ru:9443/api/v2/oauth")!)
        tokenRequest.httpMethod = "POST"
        tokenRequest.setValue("Basic \(config.saluteAuthKey)", forHTTPHeaderField: "Authorization")
        tokenRequest.setValue(UUID().uuidString, forHTTPHeaderField: "RqUID")
        tokenRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        tokenRequest.httpBody = "scope=\(config.saluteScope)".data(using: .utf8)
        let (tokenData, _) = try await URLSession.shared.data(for: tokenRequest)
        let token = try JSONDecoder().decode(SaluteTokenResponse.self, from: tokenData).accessToken

        status = "Генерирую SaluteSpeech"
        var components = URLComponents(string: "https://smartspeech.sber.ru/rest/v1/text:synthesize")!
        components.queryItems = [
            URLQueryItem(name: "format", value: "wav16"),
            URLQueryItem(name: "voice", value: config.saluteVoice),
        ]
        var synthRequest = URLRequest(url: components.url!)
        synthRequest.httpMethod = "POST"
        synthRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        synthRequest.setValue("application/text", forHTTPHeaderField: "Content-Type")
        synthRequest.httpBody = text.data(using: .utf8)
        let (audio, _) = try await URLSession.shared.data(for: synthRequest)
        return audio
    }

    private func synthesizeElevenLabs(text: String, config: AppConfig) async throws -> Data {
        guard !config.elevenLabsApiKey.isEmpty else { throw TTSServiceError.missingKey("ElevenLabs") }
        status = "Генерирую ElevenLabs"

        var components = URLComponents(string: "https://api.elevenlabs.io/v1/text-to-speech/\(config.elevenLabsVoiceId)")!
        components.queryItems = [URLQueryItem(name: "output_format", value: "mp3_44100_128")]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(config.elevenLabsApiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ElevenLabsRequest(
            text: text,
            modelId: config.elevenLabsModelId,
            voiceSettings: ElevenLabsVoiceSettings(
                stability: 0.48,
                similarityBoost: 0.78,
                style: 0.18,
                useSpeakerBoost: true
            )
        ))
        let (audio, _) = try await URLSession.shared.data(for: request)
        return audio
    }

    private func play(data: Data, extension fileExtension: String) throws {
        status = "Воспроизвожу"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("muhomor-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)
        try data.write(to: url)
        let player = try AVAudioPlayer(contentsOf: url)
        self.player = player
        player.delegate = self
        player.prepareToPlay()
        player.play()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        status = "Готов"
    }
}

private struct SaluteTokenResponse: Decodable {
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}

private struct ElevenLabsRequest: Encodable {
    let text: String
    let modelId: String
    let voiceSettings: ElevenLabsVoiceSettings

    enum CodingKeys: String, CodingKey {
        case text
        case modelId = "model_id"
        case voiceSettings = "voice_settings"
    }
}

private struct ElevenLabsVoiceSettings: Encodable {
    let stability: Double
    let similarityBoost: Double
    let style: Double
    let useSpeakerBoost: Bool

    enum CodingKeys: String, CodingKey {
        case stability
        case similarityBoost = "similarity_boost"
        case style
        case useSpeakerBoost = "use_speaker_boost"
    }
}

private enum TTSServiceError: LocalizedError {
    case missingKey(String)

    var errorDescription: String? {
        switch self {
        case .missingKey(let service):
            "\(service) ключ не задан"
        }
    }
}
