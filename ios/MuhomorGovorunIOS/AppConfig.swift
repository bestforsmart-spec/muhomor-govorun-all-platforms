import Foundation

struct AppConfig: Codable, Equatable {
    var voiceLanguage = "ru-RU"
    var rate: Double = 0.49
    var pitch: Double = 1.0
    var isDarkTheme = false

    enum CodingKeys: String, CodingKey {
        case voiceLanguage
        case rate
        case pitch
        case isDarkTheme
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        voiceLanguage = try container.decodeIfPresent(String.self, forKey: .voiceLanguage) ?? "ru-RU"
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
