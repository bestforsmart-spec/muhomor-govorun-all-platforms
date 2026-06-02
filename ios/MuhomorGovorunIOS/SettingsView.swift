import SwiftUI

struct SettingsView: View {
    @Binding var config: AppConfig
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("SaluteSpeech") {
                    SecureField("Auth key", text: $config.saluteAuthKey)
                    TextField("Scope", text: $config.saluteScope)
                    TextField("Voice", text: $config.saluteVoice)
                }

                Section("ElevenLabs") {
                    SecureField("API key", text: $config.elevenLabsApiKey)
                    TextField("Voice ID", text: $config.elevenLabsVoiceId)
                    TextField("Model ID", text: $config.elevenLabsModelId)
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
