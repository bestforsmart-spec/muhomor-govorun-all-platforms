import SwiftUI

struct SettingsView: View {
    @Binding var config: AppConfig
    @Environment(\.dismiss) private var dismiss
    @Environment(TTSService.self) private var ttsService

    var body: some View {
        NavigationStack {
            Form {
                Section("Локальный голос") {
                    TextField("Language", text: $config.voiceLanguage)
                    Slider(value: $config.rate, in: 0.35...0.62) {
                        Text("Скорость")
                    }
                    Slider(value: $config.pitch, in: 0.8...1.2) {
                        Text("Тон")
                    }
                }

                Section {
                    Button("Проверить голос") {
                        ttsService.speakLocal(text: "Проверка голоса Мухомор Говорун", config: config)
                    }

                    Button("Стоп") {
                        ttsService.stop()
                    }

                    Text(ttsService.status)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Text("Для офлайн-работы нужен установленный русский системный голос iOS. Если голос не скачан, iPhone может попросить загрузить его в настройках Accessibility/Spoken Content.")
                }
            }
            .navigationTitle("Настройки")
            .toolbar {
                Button("Готово") {
                    config.save()
                    dismiss()
                }
            }
        }
    }
}
