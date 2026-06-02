#!/usr/bin/env python3
from __future__ import annotations

import base64
import ctypes
import ctypes.wintypes
import json
import os
import queue
import ssl
import subprocess
import sys
import tempfile
import threading
import time
import uuid
import wave
from pathlib import Path
from tkinter import BOTH, END, LEFT, RIGHT, Button, Frame, Label, Radiobutton, StringVar, Text, Tk, messagebox
from urllib import error, parse, request


APP_NAME = "Мухомор - Говорун"
CONFIG_PATH = Path(__file__).with_name("config.json")
CONFIG_EXAMPLE_PATH = Path(__file__).with_name("config.example.json")


DEFAULT_CONFIG = {
    "tts_backend": "local_fast",
    "local": {
        "voice": "",
        "rate": 0,
        "volume": 100,
    },
    "salute": {
        "auth_key": "",
        "scope": "SALUTE_SPEECH_PERS",
        "voice": "Ost_24000",
        "format": "wav16",
        "curl_insecure": False,
    },
    "elevenlabs": {
        "api_key": "",
        "voice_id": "JBFqnCBsd6RMkjVDRZzb",
        "model_id": "eleven_multilingual_v2",
        "output_format": "mp3_44100_128",
        "stability": 0.48,
        "similarity_boost": 0.78,
        "style": 0.18,
    },
}


def deep_merge(defaults: dict, current: dict) -> dict:
    result = dict(defaults)
    for key, value in current.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value
    return result


def load_config() -> dict:
    if not CONFIG_PATH.exists():
        CONFIG_PATH.write_text(json.dumps(DEFAULT_CONFIG, ensure_ascii=False, indent=2), encoding="utf-8")
        if not CONFIG_EXAMPLE_PATH.exists():
            CONFIG_EXAMPLE_PATH.write_text(json.dumps(DEFAULT_CONFIG, ensure_ascii=False, indent=2), encoding="utf-8")
        return dict(DEFAULT_CONFIG)
    try:
        current = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    except Exception:
        current = {}
    return deep_merge(DEFAULT_CONFIG, current)


def save_config(config: dict) -> None:
    CONFIG_PATH.write_text(json.dumps(config, ensure_ascii=False, indent=2), encoding="utf-8")


def ssl_context(insecure: bool = False) -> ssl.SSLContext:
    if insecure:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        return ctx
    try:
        import certifi

        return ssl.create_default_context(cafile=certifi.where())
    except Exception:
        return ssl.create_default_context()


def run_powershell(script: str) -> subprocess.Popen:
    return subprocess.Popen(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def ps_quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def split_for_tts(text: str, limit: int = 4300) -> list[str]:
    words = text.replace("\n", " ").split()
    chunks: list[str] = []
    current: list[str] = []
    current_len = 0
    for word in words:
        extra = len(word) + (1 if current else 0)
        if current and current_len + extra > limit:
            chunks.append(" ".join(current))
            current = [word]
            current_len = len(word)
        else:
            current.append(word)
            current_len += extra
    if current:
        chunks.append(" ".join(current))
    return chunks


class TtsEngine:
    def __init__(self, config: dict, status_cb):
        self.config = config
        self.status_cb = status_cb
        self.process: subprocess.Popen | None = None
        self.stop_flag = threading.Event()

    def stop(self) -> None:
        self.stop_flag.set()
        if self.process and self.process.poll() is None:
            self.process.terminate()

    def speak(self, text: str, backend: str) -> None:
        self.stop_flag.clear()
        if backend == "local_fast":
            self.speak_local(text)
        elif backend == "salute_tts":
            self.speak_salute(text)
        elif backend == "elevenlabs_tts":
            self.speak_elevenlabs(text)
        else:
            self.speak_local(text)

    def speak_local(self, text: str) -> None:
        local = self.config.get("local", {})
        voice = str(local.get("voice") or "")
        rate = int(local.get("rate") or 0)
        volume = int(local.get("volume") or 100)
        encoded = base64.b64encode(text.encode("utf-16le")).decode("ascii")
        voice_line = ""
        if voice:
            voice_line = f"$s.SelectVoice({ps_quote(voice)});"
        script = (
            "Add-Type -AssemblyName System.Speech;"
            "$s=New-Object System.Speech.Synthesis.SpeechSynthesizer;"
            f"$s.Rate={rate};$s.Volume={volume};"
            f"{voice_line}"
            f"$bytes=[Convert]::FromBase64String('{encoded}');"
            "$text=[Text.Encoding]::Unicode.GetString($bytes);"
            "$s.Speak($text);"
        )
        self.status_cb("Озвучиваю локально")
        self.process = run_powershell(script)
        self.process.wait()

    def speak_salute(self, text: str) -> None:
        salute = self.config.get("salute", {})
        auth_key = str(salute.get("auth_key") or "")
        if not auth_key:
            raise RuntimeError("SaluteSpeech auth_key не задан в config.json")

        scope = str(salute.get("scope") or "SALUTE_SPEECH_PERS")
        voice = str(salute.get("voice") or "Ost_24000")
        fmt = str(salute.get("format") or "wav16")
        insecure = bool(salute.get("curl_insecure") or False)

        self.status_cb("Получаю токен SaluteSpeech")
        rq_uid = str(uuid.uuid4())
        token_req = request.Request(
            "https://ngw.devices.sberbank.ru:9443/api/v2/oauth",
            data=parse.urlencode({"scope": scope}).encode("utf-8"),
            headers={
                "Authorization": f"Basic {auth_key}",
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "application/json",
                "RqUID": rq_uid,
            },
            method="POST",
        )
        with request.urlopen(token_req, timeout=30, context=ssl_context(insecure)) as response:
            token = json.loads(response.read().decode("utf-8"))["access_token"]

        for chunk in split_for_tts(text, 3800):
            if self.stop_flag.is_set():
                return
            self.status_cb("Генерирую SaluteSpeech")
            synth_req = request.Request(
                f"https://smartspeech.sber.ru/rest/v1/text:synthesize?format={parse.quote(fmt)}&voice={parse.quote(voice)}",
                data=chunk.encode("utf-8"),
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/text",
                    "Accept": "audio/wav",
                },
                method="POST",
            )
            with request.urlopen(synth_req, timeout=60, context=ssl_context(insecure)) as response:
                wav_bytes = response.read()
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
                tmp.write(wav_bytes)
                wav_path = Path(tmp.name)
            try:
                self.play_wav(wav_path)
            finally:
                wav_path.unlink(missing_ok=True)

    def speak_elevenlabs(self, text: str) -> None:
        eleven = self.config.get("elevenlabs", {})
        api_key = str(eleven.get("api_key") or "")
        if not api_key:
            raise RuntimeError("ElevenLabs api_key не задан в config.json")

        voice_id = str(eleven.get("voice_id") or "JBFqnCBsd6RMkjVDRZzb")
        model_id = str(eleven.get("model_id") or "eleven_multilingual_v2")
        output_format = str(eleven.get("output_format") or "mp3_44100_128")
        url = f"https://api.elevenlabs.io/v1/text-to-speech/{parse.quote(voice_id)}?{parse.urlencode({'output_format': output_format})}"

        for chunk in split_for_tts(text):
            if self.stop_flag.is_set():
                return
            self.status_cb("Генерирую ElevenLabs")
            payload = {
                "text": chunk,
                "model_id": model_id,
                "voice_settings": {
                    "stability": float(eleven.get("stability") or 0.48),
                    "similarity_boost": float(eleven.get("similarity_boost") or 0.78),
                    "style": float(eleven.get("style") or 0.18),
                    "use_speaker_boost": True,
                },
            }
            req = request.Request(
                url,
                data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
                headers={"xi-api-key": api_key, "Content-Type": "application/json", "Accept": "audio/mpeg"},
                method="POST",
            )
            try:
                with request.urlopen(req, timeout=120, context=ssl_context()) as response:
                    mp3_bytes = response.read()
            except error.HTTPError as exc:
                detail = exc.read().decode("utf-8", errors="ignore")
                raise RuntimeError(f"ElevenLabs HTTP {exc.code}: {detail}") from exc
            with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp:
                tmp.write(mp3_bytes)
                mp3_path = Path(tmp.name)
            try:
                self.play_media(mp3_path)
            finally:
                mp3_path.unlink(missing_ok=True)

    def play_wav(self, path: Path) -> None:
        duration = 1.0
        try:
            with wave.open(str(path), "rb") as wav:
                duration = wav.getnframes() / float(wav.getframerate() or 1)
        except Exception:
            pass
        import winsound

        self.status_cb("Воспроизвожу")
        winsound.PlaySound(str(path), winsound.SND_FILENAME | winsound.SND_ASYNC)
        start = time.time()
        while time.time() - start < duration + 0.3:
            if self.stop_flag.is_set():
                winsound.PlaySound(None, winsound.SND_PURGE)
                return
            time.sleep(0.05)
        winsound.PlaySound(None, winsound.SND_PURGE)

    def play_media(self, path: Path) -> None:
        encoded_path = base64.b64encode(str(path).encode("utf-16le")).decode("ascii")
        script = (
            "Add-Type -AssemblyName presentationCore;"
            f"$p=[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('{encoded_path}'));"
            "$m=New-Object System.Windows.Media.MediaPlayer;"
            "$m.Open([Uri]$p);"
            "$deadline=(Get-Date).AddSeconds(10);"
            "while(-not $m.NaturalDuration.HasTimeSpan -and (Get-Date) -lt $deadline){Start-Sleep -Milliseconds 100};"
            "$m.Play();"
            "$deadline=(Get-Date).AddMinutes(30);"
            "while((Get-Date) -lt $deadline){"
            "if($m.NaturalDuration.HasTimeSpan -and $m.Position -ge $m.NaturalDuration.TimeSpan){break};"
            "Start-Sleep -Milliseconds 100"
            "};"
        )
        self.status_cb("Воспроизвожу")
        self.process = run_powershell(script)
        self.process.wait()


class HotkeyThread(threading.Thread):
    MOD_CONTROL = 0x0002
    MOD_SHIFT = 0x0004
    WM_HOTKEY = 0x0312

    def __init__(self, event_queue: queue.Queue[str]):
        super().__init__(daemon=True)
        self.event_queue = event_queue

    def run(self) -> None:
        user32 = ctypes.windll.user32
        user32.RegisterHotKey(None, 1, self.MOD_CONTROL | self.MOD_SHIFT, ord("V"))
        user32.RegisterHotKey(None, 2, self.MOD_CONTROL | self.MOD_SHIFT, ord("S"))
        msg = ctypes.wintypes.MSG()
        while user32.GetMessageW(ctypes.byref(msg), None, 0, 0) != 0:
            if msg.message == self.WM_HOTKEY:
                if msg.wParam == 1:
                    self.event_queue.put("speak_clipboard")
                elif msg.wParam == 2:
                    self.event_queue.put("stop")


class App:
    def __init__(self) -> None:
        self.config = load_config()
        self.root = Tk()
        self.root.title(APP_NAME)
        self.root.geometry("760x520")
        self.backend = StringVar(value=self.config.get("tts_backend", "local_fast"))
        self.status = StringVar(value="Готов")
        self.events: queue.Queue[str] = queue.Queue()
        self.tts = TtsEngine(self.config, self.set_status_threadsafe)
        self.worker: threading.Thread | None = None
        self.build_ui()
        if sys.platform.startswith("win"):
            HotkeyThread(self.events).start()
        self.root.after(200, self.poll_events)

    def build_ui(self) -> None:
        top = Frame(self.root)
        top.pack(fill="x", padx=14, pady=10)
        Label(top, text=APP_NAME, font=("Segoe UI", 16, "bold")).pack(side=LEFT)
        Label(top, textvariable=self.status, font=("Segoe UI", 10)).pack(side=RIGHT)

        voice = Frame(self.root)
        voice.pack(fill="x", padx=14)
        for label, value in [
            ("Локальная простая быстрая модель", "local_fast"),
            ("SaluteSpeech быстрый облачный", "salute_tts"),
            ("ElevenLabs красивый голос", "elevenlabs_tts"),
        ]:
            Radiobutton(voice, text=label, variable=self.backend, value=value, command=self.save_backend).pack(side=LEFT, padx=(0, 12))

        self.text = Text(self.root, wrap="word", font=("Segoe UI", 11), height=18)
        self.text.pack(fill=BOTH, expand=True, padx=14, pady=12)

        buttons = Frame(self.root)
        buttons.pack(fill="x", padx=14, pady=(0, 12))
        Button(buttons, text="Вставить из буфера", command=self.paste_clipboard).pack(side=LEFT)
        Button(buttons, text="Озвучить", command=self.speak_text).pack(side=LEFT, padx=8)
        Button(buttons, text="Озвучить буфер", command=self.speak_clipboard).pack(side=LEFT)
        Button(buttons, text="Стоп", command=self.stop).pack(side=LEFT, padx=8)
        Button(buttons, text="Открыть config.json", command=self.open_config).pack(side=RIGHT)

        hint = Label(
            self.root,
            text="Горячие клавиши: Ctrl+Shift+V — озвучить буфер, Ctrl+Shift+S — стоп. API-ключи задаются в config.json.",
            font=("Segoe UI", 9),
        )
        hint.pack(fill="x", padx=14, pady=(0, 10))

    def save_backend(self) -> None:
        self.config["tts_backend"] = self.backend.get()
        save_config(self.config)

    def set_status_threadsafe(self, value: str) -> None:
        self.events.put(f"status:{value}")

    def set_status(self, value: str) -> None:
        self.status.set(value)

    def paste_clipboard(self) -> None:
        try:
            value = self.root.clipboard_get()
        except Exception:
            value = ""
        if value:
            self.text.delete("1.0", END)
            self.text.insert("1.0", value)

    def current_text(self) -> str:
        return self.text.get("1.0", END).strip()

    def speak_clipboard(self) -> None:
        self.paste_clipboard()
        self.speak_text()

    def speak_text(self) -> None:
        text = self.current_text()
        if not text:
            messagebox.showinfo(APP_NAME, "Введите текст или вставьте его из буфера.")
            return
        if self.worker and self.worker.is_alive():
            messagebox.showinfo(APP_NAME, "Озвучка уже идет. Нажмите Стоп.")
            return
        self.save_backend()
        self.config = load_config()
        self.tts.config = self.config
        backend = self.backend.get()
        self.worker = threading.Thread(target=self.run_tts, args=(text, backend), daemon=True)
        self.worker.start()

    def run_tts(self, text: str, backend: str) -> None:
        try:
            self.tts.speak(text, backend)
            self.events.put("status:Готов")
        except Exception as exc:
            self.events.put(f"error:{exc}")

    def stop(self) -> None:
        self.tts.stop()
        self.set_status("Остановлено")

    def open_config(self) -> None:
        if not CONFIG_PATH.exists():
            save_config(self.config)
        os.startfile(str(CONFIG_PATH))

    def poll_events(self) -> None:
        while True:
            try:
                event = self.events.get_nowait()
            except queue.Empty:
                break
            if event == "speak_clipboard":
                self.speak_clipboard()
            elif event == "stop":
                self.stop()
            elif event.startswith("status:"):
                self.set_status(event.split(":", 1)[1])
            elif event.startswith("error:"):
                self.set_status("Ошибка")
                messagebox.showerror(APP_NAME, event.split(":", 1)[1])
        self.root.after(200, self.poll_events)

    def run(self) -> None:
        self.root.mainloop()


if __name__ == "__main__":
    App().run()
