import SwiftUI

struct SettingsView: View {
    @Binding var config: AppConfig
    @Environment(\.dismiss) private var dismiss

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
