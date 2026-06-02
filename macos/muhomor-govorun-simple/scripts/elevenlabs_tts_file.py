#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import ssl
import sys
import tempfile
from pathlib import Path
from urllib import error, parse, request


DEFAULT_MODEL = "eleven_multilingual_v2"
DEFAULT_VOICE_ID = "JBFqnCBsd6RMkjVDRZzb"
DEFAULT_OUTPUT_FORMAT = "mp3_44100_128"


def env_paths() -> list[Path]:
    home = Path.home()
    paths = [
        os.environ.get("ELEVENLABS_ENV_FILE"),
        str(home / ".muhomor-govorun" / "local-ai-tools" / "config" / "elevenlabs.env"),
    ]
    return [Path(path).expanduser() for path in paths if path]


def env_value(key: str) -> str | None:
    value = os.environ.get(key)
    if value:
        return value
    for path in env_paths():
        if not path.exists():
            continue
        for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            current_key, current_value = line.split("=", 1)
            if current_key.strip() == key:
                value = current_value.strip().strip('"').strip("'")
                if value:
                    return value
    return None


def ssl_context() -> ssl.SSLContext:
    try:
        import certifi

        return ssl.create_default_context(cafile=certifi.where())
    except Exception:
        return ssl.create_default_context()


def split_for_tts(text: str, limit: int = 4500) -> list[str]:
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


def synth_chunk(text: str, out_mp3: Path) -> None:
    api_key = env_value("ELEVENLABS_API_KEY") or env_value("XI_API_KEY")
    if not api_key:
        raise RuntimeError("ELEVENLABS_API_KEY is not configured")

    voice_id = env_value("ELEVENLABS_VOICE_ID") or DEFAULT_VOICE_ID
    model_id = env_value("ELEVENLABS_MODEL_ID") or DEFAULT_MODEL
    output_format = env_value("ELEVENLABS_OUTPUT_FORMAT") or DEFAULT_OUTPUT_FORMAT
    stability = float(env_value("ELEVENLABS_STABILITY") or "0.48")
    similarity = float(env_value("ELEVENLABS_SIMILARITY_BOOST") or "0.78")
    style = float(env_value("ELEVENLABS_STYLE") or "0.18")

    query = parse.urlencode({"output_format": output_format})
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{parse.quote(voice_id)}?{query}"
    payload = {
        "text": text,
        "model_id": model_id,
        "voice_settings": {
            "stability": stability,
            "similarity_boost": similarity,
            "style": style,
            "use_speaker_boost": True,
        },
    }
    req = request.Request(
        url,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={
            "xi-api-key": api_key,
            "Content-Type": "application/json",
            "Accept": "audio/mpeg",
        },
        method="POST",
    )
    try:
        with request.urlopen(req, timeout=120, context=ssl_context()) as response:
            out_mp3.write_bytes(response.read())
    except error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="ignore")
        raise RuntimeError(f"ElevenLabs TTS failed: HTTP {exc.code}: {detail}") from exc


def synthesize(text: str, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    chunks = split_for_tts(text)
    if len(chunks) == 1:
        synth_chunk(chunks[0], output)
        return

    with tempfile.TemporaryDirectory() as tmp:
        tmp_dir = Path(tmp)
        parts: list[Path] = []
        for index, chunk in enumerate(chunks, start=1):
            part = tmp_dir / f"elevenlabs_part_{index:02d}.mp3"
            synth_chunk(chunk, part)
            parts.append(part)
        output.write_bytes(b"".join(part.read_bytes() for part in parts))


def main() -> None:
    if len(sys.argv) < 3:
        raise SystemExit("usage: elevenlabs_tts_file.py <input.txt> <output.mp3>")
    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])
    text = input_path.read_text(encoding="utf-8").strip()
    if not text:
        raise SystemExit("ELEVENLABS_TTS_EMPTY_TEXT")
    synthesize(text, output_path)
    print("ELEVENLABS_TTS_OK")


if __name__ == "__main__":
    main()
