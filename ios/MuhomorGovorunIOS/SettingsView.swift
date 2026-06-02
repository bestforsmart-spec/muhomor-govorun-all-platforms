import SwiftUI

struct SettingsView: View {
    @Binding var config: AppConfig
    @Environment(\.dismiss) private var dismiss
    @Environment(TTSService.self) private var ttsService

    var body: some View {
        NavigationStack {
            ZStack {
                SettingsBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("Локальный голос", systemImage: "waveform")
                                    .font(.headline)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Язык")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)

                                    TextField("ru-RU", text: $config.voiceLanguage)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .padding(12)
                                        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
                                }

                                SettingSlider(
                                    title: "Скорость",
                                    value: $config.rate,
                                    range: 0.35...0.62,
                                    icon: "speedometer"
                                )

                                SettingSlider(
                                    title: "Тон",
                                    value: $config.pitch,
                                    range: 0.8...1.2,
                                    icon: "slider.horizontal.below.sun.max"
                                )
                            }
                        }

                        SettingsCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    Button {
                                        ttsService.speakLocal(text: "Проверка голоса Мухомор Говорун", config: config)
                                    } label: {
                                        Label("Проверить", systemImage: "speaker.wave.2.fill")
                                    }
                                    .buttonStyle(SettingsPrimaryButtonStyle())

                                    Button {
                                        ttsService.stop()
                                    } label: {
                                        Label("Стоп", systemImage: "stop.fill")
                                    }
                                    .buttonStyle(SettingsSecondaryButtonStyle())
                                }

                                Text(ttsService.status)
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }

                        SettingsCard {
                            Label {
                                Text("Для офлайн-работы нужен установленный русский системный голос iOS. Если голос не скачан, iPhone может попросить загрузить его в настройках Accessibility/Spoken Content.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(Color(red: 0.58, green: 0.18, blue: 0.16))
                            }
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Готово") {
                    config.save()
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }
}

private struct SettingsBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.96, blue: 0.92),
                Color(red: 0.91, green: 0.94, blue: 0.93),
                Color(red: 0.96, green: 0.95, blue: 0.98)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct SettingsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            }
    }
}

private struct SettingSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(value, format: .number.precision(.fractionLength(2)))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Slider(value: $value, in: range)
                .tint(Color(red: 0.58, green: 0.18, blue: 0.16))
        }
    }
}

private struct SettingsPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(
                Color(red: 0.06, green: 0.08, blue: 0.09)
                    .opacity(configuration.isPressed ? 0.82 : 1),
                in: RoundedRectangle(cornerRadius: 8)
            )
    }
}

private struct SettingsSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .foregroundStyle(Color(red: 0.06, green: 0.08, blue: 0.09))
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(
                .white.opacity(configuration.isPressed ? 0.55 : 0.78),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            }
    }
}
