import SwiftUI
import UIKit

struct ContentView: View {
    @Binding var config: AppConfig
    @Environment(TTSService.self) private var ttsService
    @State private var text = ""
    @State private var showingSettings = false
    private var isTextEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()

                VStack(spacing: 18) {
                    PremiumHeader()

                    ComposerCard(text: $text)

                    ActionBar(
                        isTextEmpty: isTextEmpty,
                        paste: {
                            text = UIPasteboard.general.string ?? text
                        },
                        speak: {
                            ttsService.speakLocal(text: text, config: config)
                        },
                        stop: {
                            ttsService.stop()
                        }
                    )

                    StatusPill(status: ttsService.status)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 18)
            }
            .navigationTitle("ShromSpeak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Настройки")
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(config: $config)
            }
        }
    }
}

private struct PremiumBackground: View {
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

private struct PremiumHeader: View {
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image("MuhomorShield")
                .resizable()
                .scaledToFill()
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.55), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 7) {
                Text("ShromSpeak")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))

                Text("Офлайн-голос для выделенного текста")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                    Text("Локально")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(red: 0.12, green: 0.36, blue: 0.32))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.7), in: Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.55), lineWidth: 1)
        }
    }
}

private struct ComposerCard: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Текст", systemImage: "text.alignleft")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("\(text.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 230)
                    .padding(.horizontal, -4)
                    .padding(.vertical, -8)

                if text.isEmpty {
                    Text("Вставь или набери текст для озвучки")
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct ActionBar: View {
    let isTextEmpty: Bool
    let paste: () -> Void
    let speak: () -> Void
    let stop: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: paste) {
                Label("Буфер", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(SecondaryActionButtonStyle())

            Button(action: speak) {
                Label("Озвучить", systemImage: "speaker.wave.2.fill")
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(isTextEmpty)

            Button(action: stop) {
                Label("Стоп", systemImage: "stop.fill")
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
    }
}

private struct StatusPill: View {
    let status: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(red: 0.13, green: 0.58, blue: 0.45))
                .frame(width: 7, height: 7)

            Text(status)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.58), in: Capsule())
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                Color(red: 0.06, green: 0.08, blue: 0.09)
                    .opacity(configuration.isPressed ? 0.82 : 1),
                in: RoundedRectangle(cornerRadius: 8)
            )
    }
}

private struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .foregroundStyle(Color(red: 0.06, green: 0.08, blue: 0.09))
            .frame(maxWidth: .infinity, minHeight: 48)
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

#Preview {
    ContentView(config: .constant(AppConfig()))
        .environment(TTSService())
}
