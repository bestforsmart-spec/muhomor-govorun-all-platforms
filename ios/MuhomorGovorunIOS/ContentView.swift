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

                VStack(spacing: 12) {
                    BrandTopBar {
                        showingSettings = true
                    }

                    ThemeBanner()

                    ComposerCard(text: $text)
                        .frame(maxHeight: .infinity)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BottomControlDock(
                    status: ttsService.status,
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
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingSettings) {
                SettingsView(config: $config)
            }
        }
    }
}

struct ShromPalette {
    let isDark: Bool

    init(_ colorScheme: ColorScheme) {
        isDark = colorScheme == .dark
    }

    var backgroundColors: [Color] {
        if isDark {
            return [
                Color(red: 0.04, green: 0.04, blue: 0.05),
                Color(red: 0.10, green: 0.07, blue: 0.08),
                Color(red: 0.05, green: 0.09, blue: 0.09)
            ]
        }
        return [
            Color(red: 0.98, green: 0.96, blue: 0.92),
            Color(red: 0.91, green: 0.94, blue: 0.93),
            Color(red: 0.96, green: 0.95, blue: 0.98)
        ]
    }

    var card: Color {
        isDark ? Color.white.opacity(0.08) : Color.white.opacity(0.78)
    }

    var cardStrong: Color {
        isDark ? Color.white.opacity(0.12) : Color.white.opacity(0.76)
    }

    var field: Color {
        isDark ? Color.black.opacity(0.22) : Color.white.opacity(0.72)
    }

    var stroke: Color {
        isDark ? Color.white.opacity(0.13) : Color.black.opacity(0.06)
    }

    var subtleStroke: Color {
        isDark ? Color.white.opacity(0.16) : Color.black.opacity(0.08)
    }

    var primaryText: Color {
        isDark ? Color(red: 0.98, green: 0.95, blue: 0.89) : Color(red: 0.06, green: 0.08, blue: 0.09)
    }

    var secondaryText: Color {
        isDark ? Color(red: 0.74, green: 0.70, blue: 0.65) : Color.secondary
    }

    var accent: Color {
        isDark ? Color(red: 0.92, green: 0.34, blue: 0.28) : Color(red: 0.58, green: 0.18, blue: 0.16)
    }

    var success: Color {
        isDark ? Color(red: 0.32, green: 0.76, blue: 0.62) : Color(red: 0.13, green: 0.58, blue: 0.45)
    }

    var primaryButton: Color {
        isDark ? Color(red: 0.92, green: 0.34, blue: 0.28) : Color(red: 0.06, green: 0.08, blue: 0.09)
    }

    var primaryButtonText: Color {
        Color.white
    }

    var secondaryButtonText: Color {
        primaryText
    }
}

private struct PremiumBackground: View {
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

private struct BrandTopBar: View {
    @Environment(\.colorScheme) private var colorScheme
    let openSettings: () -> Void

    var body: some View {
        let palette = ShromPalette(colorScheme)

        HStack(spacing: 12) {
            Text("SHROOMSPEAK 🍄")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(palette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .background(palette.cardStrong, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(palette.stroke, lineWidth: 1)
                }

            Button(action: openSettings) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
                    .frame(width: 56, height: 56)
            }
            .background(palette.cardStrong, in: Circle())
            .overlay {
                Circle()
                    .stroke(palette.stroke, lineWidth: 1)
            }
            .accessibilityLabel("Настройки")
        }
    }
}

private struct ThemeBanner: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = ShromPalette(colorScheme)
        let imageName = palette.isDark ? "ShroomSpeakBannerDark" : "ShroomSpeakBannerLight"

        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(palette.stroke, lineWidth: 1)
            }
            .shadow(color: .black.opacity(palette.isDark ? 0.28 : 0.10), radius: 12, y: 6)
            .accessibilityHidden(true)
    }
}

private struct ComposerCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String

    var body: some View {
        let palette = ShromPalette(colorScheme)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Текст", systemImage: "text.alignleft")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)

                Spacer()

                Text("\(text.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(palette.secondaryText)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 260, maxHeight: .infinity)
                    .padding(.horizontal, -4)
                    .padding(.vertical, -8)

                if text.isEmpty {
                    Text("Вставь или набери текст для озвучки")
                        .foregroundStyle(palette.secondaryText)
                        .padding(.top, 2)
                        .allowsHitTesting(false)
                }
            }
            .foregroundStyle(palette.primaryText)
        }
        .padding(16)
        .frame(maxHeight: .infinity)
        .background(palette.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(palette.stroke, lineWidth: 1)
        }
    }
}

private struct BottomControlDock: View {
    @Environment(\.colorScheme) private var colorScheme
    let status: String
    let isTextEmpty: Bool
    let paste: () -> Void
    let speak: () -> Void
    let stop: () -> Void

    var body: some View {
        let palette = ShromPalette(colorScheme)

        VStack(spacing: 10) {
            ActionBar(
                isTextEmpty: isTextEmpty,
                paste: paste,
                speak: speak,
                stop: stop
            )

            StatusPill(status: status)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.stroke)
                .frame(height: 1)
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
    @Environment(\.colorScheme) private var colorScheme
    let status: String

    var body: some View {
        let palette = ShromPalette(colorScheme)

        HStack(spacing: 8) {
            Circle()
                .fill(palette.success)
                .frame(width: 7, height: 7)

            Text(status)
                .font(.footnote.weight(.medium))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(palette.cardStrong, in: Capsule())
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let palette = ShromPalette(colorScheme)

        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(palette.primaryButtonText)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                palette.primaryButton
                    .opacity(configuration.isPressed ? 0.82 : 1),
                in: RoundedRectangle(cornerRadius: 8)
            )
    }
}

private struct SecondaryActionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let palette = ShromPalette(colorScheme)

        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .foregroundStyle(palette.secondaryButtonText)
            .frame(maxWidth: .infinity, minHeight: 48)
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

#Preview {
    ContentView(config: .constant(AppConfig()))
        .environment(TTSService())
}
