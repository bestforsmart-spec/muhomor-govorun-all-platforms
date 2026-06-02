#!/usr/bin/env python3
import re
import sys


text = sys.stdin.read().strip()
if not text:
    print("")
    raise SystemExit(0)

# Make phrasing calmer and less abrupt for system TTS.
text = re.sub(r"\s*[-–—]\s*", ", ", text)
text = re.sub(r"\s*;\s*", ". ", text)
text = re.sub(r"\s*:\s*", ". ", text)
text = re.sub(r"([.!?])([А-ЯA-ZЁ])", r"\1 \2", text)
text = re.sub(r"\s+", " ", text).strip()

# Add soft pauses after short clauses if punctuation is sparse.
text = re.sub(r",\s*", ", ", text)
text = re.sub(r"\.\s*", ". ", text)

print(text)
