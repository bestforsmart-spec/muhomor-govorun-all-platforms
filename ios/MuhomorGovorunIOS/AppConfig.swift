import Foundation

enum VoiceGender: String, Codable, CaseIterable, Identifiable {
    case female
    case male

    var id: String { rawValue }

    var title: String {
        switch self {
        case .female:
            return "Женский"
        case .male:
            return "Мужской"
        }
    }
}

struct AppConfig: Codable, Equatable {
    var voiceLanguage = "ru-RU"
    var voiceGender: VoiceGender = .female
    var rate: Double = 0.49
    var pitch: Double = 1.0
    var isDarkTheme = false

    enum CodingKeys: String, CodingKey {
        case voiceLanguage
        case voiceGender
        case rate
        case pitch
        case isDarkTheme
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        voiceLanguage = try container.decodeIfPresent(String.self, forKey: .voiceLanguage) ?? "ru-RU"
        voiceGender = try container.decodeIfPresent(VoiceGender.self, forKey: .voiceGender) ?? .female
        rate = try container.decodeIfPresent(Double.self, forKey: .rate) ?? 0.49
        pitch = try container.decodeIfPresent(Double.self, forKey: .pitch) ?? 1.0
        isDarkTheme = try container.decodeIfPresent(Bool.self, forKey: .isDarkTheme) ?? false
    }

    static func load() -> AppConfig {
        guard let data = UserDefaults.standard.data(forKey: "muhomor.local.config"),
              let value = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return AppConfig()
        }
        return value
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: "muhomor.local.config")
    }
}
