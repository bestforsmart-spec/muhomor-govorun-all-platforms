# ShromSpeak для Android

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

Или соберите из терминала:

```bash
cd android
gradle assembleDebug
```

Готовый debug APK появляется здесь:

```text
android/app/build/outputs/apk/debug/app-debug.apk
```

Debug APK уже подписан debug-ключом Android и подходит для ручной установки на телефон. Для Google Play нужна отдельная release-сборка с production signing key.

## Ключи

Ключи вводятся прямо в приложении и хранятся локально в `SharedPreferences`:

- `salute_auth_key`
- `elevenlabs_api_key`
