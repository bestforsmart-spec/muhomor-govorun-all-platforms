# Мухомор - Говорун · all platforms

Монорепозиторий с четырьмя вариантами сервиса озвучки:

- `macos/` — macOS/Hammerspoon версия.
- `windows/` — Windows Python/Tk версия.
- `android/` — Android MVP.
- `ios/` — iPhone SwiftUI MVP.

Во всех вариантах оставлены только три режима TTS:

- локальная простая быстрая модель;
- SaluteSpeech как быстрый облачный голос;
- ElevenLabs как красивый голос.

## Готовые архивы

Папка `release-artifacts/` содержит уже собранные архивы для macOS и Windows:

- `muhomor-govorun-simple-macos.zip`
- `muhomor-govorun-windows.zip`

Android и iOS добавлены как buildable source projects. В этой Codex-сессии APK/IPA не были собраны, потому что локально нет Java/Gradle и полноценного Xcode.

## Платформенные ограничения

macOS и Windows могут работать ближе к “надстройке”: брать буфер/выделенный текст и запускаться горячими клавишами.

Android может принимать текст через системное `Поделиться`, буфер и локальный TTS.

iPhone не даёт обычному приложению глобально читать выделенный текст из других приложений. Поэтому iOS MVP работает через поле текста и буфер. Для следующей версии нужен Share Extension.

## Секреты

API-ключи не коммитятся. В репозитории есть только example/default конфиги без секретов.

Нужные ключи:

- SaluteSpeech auth key.
- ElevenLabs API key.
- GigaChat/Brave для macOS summary/search сценариев.

## Статус

Сделано:

- единая продуктовая схема на 3 TTS-режима;
- macOS архив;
- Windows архив;
- Android source MVP;
- iOS SwiftUI source MVP;
- документация по сборке и ограничениям.

Следующая итерация:

- Android экран настроек для ключей вместо `SharedPreferences` через tooling;
- iOS Share Extension;
- CI для сборки Android APK и iOS archive.
