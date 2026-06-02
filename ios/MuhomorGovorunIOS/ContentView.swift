import SwiftUI
import UIKit

struct ContentView: View {
    @Binding var config: AppConfig
    @Environment(TTSService.self) private var ttsService
    @State private var text = ""
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Голос", selection: $config.backend) {
                    ForEach(VoiceBackend.allCases) { backend in
                        Text(backend.title).tag(backend)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: config) { _, newValue in
                    newValue.save()
                }

                TextEditor(text: $text)
                    .font(.body)
                    .overlay {
                        if text.isEmpty {
                            Text("Вставьте текст или отправьте его сюда через буфер.")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack {
                    Button("Буфер") {
                        text = UIPasteboard.general.string ?? text
                    }
                    .buttonStyle(.bordered)

                    Button("Озвучить") {
                        Task { await ttsService.speak(text: text, config: config) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Стоп") {
                        ttsService.stop()
                    }
                    .buttonStyle(.bordered)
                }

                Text(ttsService.status)
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
            .padding()
            .navigationTitle("Мухомор - Говорун")
            .toolbar {
                Button("Настройки") {
                    showingSettings = true
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(config: $config)
            }
        }
    }
}

#Preview {
    ContentView(config: .constant(AppConfig()))
        .environment(TTSService())
}
