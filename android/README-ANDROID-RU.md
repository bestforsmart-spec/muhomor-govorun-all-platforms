# Мухомор - Говорун для Android

Нативный Android MVP с тремя режимами озвучки:

- локальный быстрый Android Text-to-Speech;
- SaluteSpeech быстрый облачный;
- ElevenLabs красивый голос.

## Сценарии

- вставить текст из буфера;
- принять текст через `Поделиться` из другого приложения;
- озвучить;
- остановить озвучку.

## Сборка

Откройте папку `android/` в Android Studio и соберите `app`.

Локально в этой Codex-сессии APK не собран, потому что в окружении нет Java Runtime и Gradle. Проект подготовлен как Android Studio/Gradle source project.

## Ключи

Ключи вводятся прямо в приложении и хранятся локально в `SharedPreferences`:

- `salute_auth_key`
- `elevenlabs_api_key`
