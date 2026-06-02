import AVFoundation
import NaturalLanguage
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let synth = AVSpeechSynthesizer()
    private let statusLabel = UILabel()
    private let textView = UITextView()
    private var sharedText = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        loadSharedText()
    }

    private func buildUI() {
        view.backgroundColor = UIColor(red: 0.97, green: 0.97, blue: 0.94, alpha: 1)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Готовлю текст"
        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.textColor = .label

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.font = .preferredFont(forTextStyle: .body)
        textView.backgroundColor = .secondarySystemBackground
        textView.layer.cornerRadius = 8

        let speakButton = UIButton(type: .system)
        speakButton.translatesAutoresizingMaskIntoConstraints = false
        speakButton.setTitle("Озвучить", for: .normal)
        speakButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        speakButton.addTarget(self, action: #selector(speak), for: .touchUpInside)

        let stopButton = UIButton(type: .system)
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.setTitle("Стоп", for: .normal)
        stopButton.addTarget(self, action: #selector(stop), for: .touchUpInside)

        let doneButton = UIButton(type: .system)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.setTitle("Готово", for: .normal)
        doneButton.addTarget(self, action: #selector(done), for: .touchUpInside)

        let buttons = UIStackView(arrangedSubviews: [speakButton, stopButton, doneButton])
        buttons.translatesAutoresizingMaskIntoConstraints = false
        buttons.axis = .horizontal
        buttons.distribution = .fillEqually
        buttons.spacing = 12

        view.addSubview(statusLabel)
        view.addSubview(textView)
        view.addSubview(buttons)

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            textView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.heightAnchor.constraint(equalToConstant: 120),

            buttons.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 12),
            buttons.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            buttons.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            buttons.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }

    private func loadSharedText() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let providers = item.attachments else {
            statusLabel.text = "Текст не найден"
            return
        }

        let supportedTypes = [UTType.plainText.identifier, "public.text"]
        for provider in providers {
            guard let type = supportedTypes.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
                continue
            }
            provider.loadItem(forTypeIdentifier: type, options: nil) { [weak self] item, _ in
                let text = (item as? String) ?? (item as? NSAttributedString)?.string ?? ""
                DispatchQueue.main.async {
                    self?.applySharedText(text)
                }
            }
            return
        }

        statusLabel.text = "Выделенный текст не передан"
    }

    private func applySharedText(_ text: String) {
        sharedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        textView.text = sharedText
        statusLabel.text = sharedText.isEmpty ? "Текст пуст" : "Готово к озвучке"
        if !sharedText.isEmpty {
            speak()
        }
    }

    @objc private func speak() {
        let text = (textView.text ?? sharedText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            statusLabel.text = "Текст пуст"
            return
        }
        synth.stopSpeaking(at: .immediate)
        do {
            try activatePlaybackSession()
        } catch {
            statusLabel.text = "Ошибка аудио: \(error.localizedDescription)"
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.voice(for: text)
        utterance.rate = 0.49
        statusLabel.text = "Озвучиваю локально"
        synth.speak(utterance)
    }

    @objc private func stop() {
        synth.stopSpeaking(at: .immediate)
        statusLabel.text = "Остановлено"
    }

    @objc private func done() {
        synth.stopSpeaking(at: .immediate)
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func activatePlaybackSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true)
    }

    private static func voice(for text: String) -> AVSpeechSynthesisVoice? {
        let languageCode = detectedLanguageCode(from: text)
        return voice(languageCode: languageCode) ?? AVSpeechSynthesisVoice(language: "ru-RU")
    }

    private static func detectedLanguageCode(from text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        if let language = recognizer.dominantLanguage, language.rawValue != "und" {
            return language.rawValue
        }

        if text.range(of: "\\p{Cyrillic}", options: .regularExpression) != nil {
            return "ru"
        }

        if text.range(of: "\\p{Latin}", options: .regularExpression) != nil {
            return "en"
        }

        return "ru"
    }

    private static func voice(languageCode: String) -> AVSpeechSynthesisVoice? {
        let normalizedCode = languageCode.lowercased()
        return AVSpeechSynthesisVoice.speechVoices().first { voice in
            let language = voice.language.lowercased()
            return language == normalizedCode || language.hasPrefix("\(normalizedCode)-")
        }
    }
}
