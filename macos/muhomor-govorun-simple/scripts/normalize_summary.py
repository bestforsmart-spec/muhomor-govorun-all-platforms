#!/usr/bin/env python3
from pathlib import Path
import re
import sys


def clean_summary(text: str) -> str:
    text = text.replace("```", " ")
    text = re.sub(r"^=+\s*$", "", text, flags=re.M)
    text = re.sub(r"^\s*Thinking\.\.\.\s*$", "", text, flags=re.M | re.I)
    text = re.sub(r"^(Итог|Кратко|Основной текст)\s*:\s*", "", text.strip(), flags=re.I)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def looks_bad(text: str) -> bool:
    if not text or len(text) < 12:
      return True
    if re.search(r"[\u3400-\u9fff]", text):
      return True
    latin = len(re.findall(r"[A-Za-z]", text))
    cyr = len(re.findall(r"[А-Яа-яЁё]", text))
    if latin > max(8, cyr // 2):
      return True
    return False


def fallback_summary(text: str) -> str:
    normalized = re.sub(r"\s+", " ", text).strip()
    parts = [p.strip() for p in re.split(r"(?<=[.!?])\s+", normalized) if p.strip()]
    if not parts:
      return normalized[:280].strip()
    summary = " ".join(parts[:2]).strip()
    if len(summary) > 280:
      summary = summary[:277].rstrip() + "..."
    return summary


if len(sys.argv) != 3:
    print("usage: normalize_summary.py <clean_input_file> <raw_summary_file>", file=sys.stderr)
    raise SystemExit(1)

source_text = Path(sys.argv[1]).read_text(errors="ignore").strip()
raw_summary = Path(sys.argv[2]).read_text(errors="ignore")
summary = clean_summary(raw_summary)

if looks_bad(summary):
    summary = fallback_summary(source_text)

print(summary)
