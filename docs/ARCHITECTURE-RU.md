# Архитектура

## Единая модель голоса

```text
text -> selected TTS backend -> audio playback
```

Поддерживаемые backend:

- `local_fast`
- `salute_tts`
- `elevenlabs_tts`

## macOS

Hammerspoon UI и shell/Python scripts:

- local: macOS `say`;
- SaluteSpeech: OAuth + synthesize REST;
- ElevenLabs: REST text-to-speech.

## Windows

Python/Tk:

- local: Windows SAPI через PowerShell `System.Speech`;
- SaluteSpeech: Python `urllib`;
- ElevenLabs: Python `urllib`;
- playback: WAV через `winsound`, MP3 через PowerShell `MediaPlayer`.

## Android

Native Android Java MVP:

- local: `android.speech.tts.TextToSpeech`;
- SaluteSpeech: `HttpURLConnection`;
- ElevenLabs: `HttpURLConnection`;
- playback: `MediaPlayer`;
- input: text field, clipboard, `ACTION_SEND`.

## iOS

SwiftUI local-only app + Share Extension:

- local: `AVSpeechSynthesizer`;
- extension: `com.apple.share-services`, display name `Озвучить`;
- input: selected/shared text from Share Sheet;
- network: not used;
- settings: `UserDefaults`.

## Безопасность ключей

Репозиторий не содержит рабочих ключей. Конфиги с секретами должны храниться только локально на устройстве или в секретах CI.
