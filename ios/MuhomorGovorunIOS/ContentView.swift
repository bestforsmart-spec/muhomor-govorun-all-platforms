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
                HStack(alignment: .center, spacing: 12) {
                    Image("MuhomorShield")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Локальная озвучка iPhone")
                            .font(.headline)

                        Text("Мухомор с щитом говорит офлайн")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                TextEditor(text: $text)
                    .font(.body)
                    .overlay {
                        if text.isEmpty {
                            Text("Текст для озвучки")
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
                        ttsService.speakLocal(text: text, config: config)
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

                Spacer(minLength: 0)
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
