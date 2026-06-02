import Foundation

struct AppConfig: Codable, Equatable {
    var voiceLanguage = "ru-RU"
    var rate: Double = 0.49
    var pitch: Double = 1.0

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
