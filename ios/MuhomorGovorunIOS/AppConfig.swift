import Foundation

enum VoiceBackend: String, CaseIterable, Identifiable {
    case localFast
    case salute
    case elevenLabs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .localFast: "Локальная простая быстрая модель"
        case .salute: "SaluteSpeech быстрый облачный"
        case .elevenLabs: "ElevenLabs красивый голос"
        }
    }
}

struct AppConfig: Codable, Equatable {
    var backend: VoiceBackend = .localFast
    var saluteAuthKey = ""
    var saluteScope = "SALUTE_SPEECH_PERS"
    var saluteVoice = "Ost_24000"
    var elevenLabsApiKey = ""
    var elevenLabsVoiceId = "JBFqnCBsd6RMkjVDRZzb"
    var elevenLabsModelId = "eleven_multilingual_v2"

    static func load() -> AppConfig {
        guard let data = UserDefaults.standard.data(forKey: "muhomor.config"),
              let value = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return AppConfig()
        }
        return value
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: "muhomor.config")
    }
}
