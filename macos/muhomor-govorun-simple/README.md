# Мухомор - Говорун simple

Упрощенная версия сервиса для озвучки текста и AI-пересказа с голосом.

## Три варианта озвучки

- `Локальная простая быстрая модель` — системный локальный голос macOS, работает без облачного TTS.
- `SaluteSpeech: быстрый облачный` — быстрый облачный голос через SaluteSpeech.
- `ElevenLabs: красивый голос` — более красивый облачный голос через ElevenLabs.

Другие голосовые варианты из прежней версии убраны из меню и установщика.

## Основные команды

- `Озвучка текста` — проговорить выделенный или скопированный текст.
- `Саммари и озвучка` — сделать краткий пересказ и проговорить его.
- `Brave поиск + GPT-5.5 голосом` — найти информацию и озвучить ответ.
- `Стоп озвучка` — остановить текущий голос.

## Установка macOS

1. Откройте папку проекта.
2. Запустите `enterprise-install.command`.
3. Введите ключи SaluteSpeech, GigaChat, Brave Search и ElevenLabs при необходимости.
4. Выберите голос по умолчанию: локальный, SaluteSpeech или ElevenLabs.

Ключи сохраняются локально в:

- `~/.muhomor-govorun/local-ai-tools/config/salute_speech.env`
- `~/.muhomor-govorun/local-ai-tools/config/gigachat.env`
- `~/.muhomor-govorun/local-ai-tools/config/brave_search.env`
- `~/.muhomor-govorun/local-ai-tools/config/elevenlabs.env`
- `~/.muhomor-govorun/local-ai-tools/config/voice_extension_settings.json`

## Проверка

Запустите `doctor.command` или пункт меню `Проверить подключения`.
