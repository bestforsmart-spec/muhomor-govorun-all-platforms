import SwiftUI

struct SettingsView: View {
    @Binding var config: AppConfig
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(TTSService.self) private var ttsService

    var body: some View {
        NavigationStack {
            ZStack {
                SettingsBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsCard {
                            Toggle(isOn: $config.isDarkTheme) {
                                Label("Темная тема", systemImage: config.isDarkTheme ? "moon.fill" : "sun.max.fill")
                                    .font(.headline)
                            }
                            .tint(ShromPalette(colorScheme).accent)
                        }

                        SettingsCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("Локальный голос", systemImage: "waveform")
                                    .font(.headline)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Голос")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)

                                    Picker("Голос", selection: $config.voiceGender) {
                                        ForEach(VoiceGender.allCases) { gender in
                                            Text(gender.title)
                                                .tag(gender)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }

                                HStack(spacing: 8) {
                                    Image(systemName: "globe")
                                        .font(.caption.weight(.semibold))

                                    Text("Язык определяется автоматически")
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundStyle(ShromPalette(colorScheme).secondaryText)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(ShromPalette(colorScheme).field, in: RoundedRectangle(cornerRadius: 8))

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
                                    .foregroundStyle(ShromPalette(colorScheme).secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(ShromPalette(colorScheme).accent)
                            }
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: config) { _, newValue in
                newValue.save()
            }
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = ShromPalette(colorScheme)

        LinearGradient(
            colors: palette.backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct SettingsCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let palette = ShromPalette(colorScheme)

        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(palette.primaryText)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(palette.stroke, lineWidth: 1)
            }
    }
}

private struct SettingSlider: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let icon: String

    var body: some View {
        let palette = ShromPalette(colorScheme)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)

                Spacer()

                Text(value, format: .number.precision(.fractionLength(2)))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
            }

            Slider(value: $value, in: range)
                .tint(palette.accent)
        }
    }
}

private struct SettingsPrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let palette = ShromPalette(colorScheme)

        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .foregroundStyle(palette.primaryButtonText)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(
                palette.primaryButton
                    .opacity(configuration.isPressed ? 0.82 : 1),
                in: RoundedRectangle(cornerRadius: 8)
            )
    }
}

private struct SettingsSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let palette = ShromPalette(colorScheme)

        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .foregroundStyle(palette.secondaryButtonText)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(
                palette.cardStrong.opacity(configuration.isPressed ? 0.72 : 1),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(palette.subtleStroke, lineWidth: 1)
            }
    }
}
