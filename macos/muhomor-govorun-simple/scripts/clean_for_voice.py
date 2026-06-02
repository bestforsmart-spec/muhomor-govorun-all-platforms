#!/usr/bin/env python3
from pathlib import Path
import re
import sys

if len(sys.argv) < 2:
    print('usage: clean_for_voice.py <file>', file=sys.stderr)
    raise SystemExit(1)

text = Path(sys.argv[1]).read_text(errors='ignore')

# remove obvious runtime/stat lines
bad_patterns = [
    r'^Prompt:\s*\d+\s+tokens.*$',
    r'^Generation:\s*\d+\s+tokens.*$',
    r'^Peak memory:\s*.*$',
    r'^Throughput:.*$',
    r'^Loading model.*$',
    r'^Fetching .*$',
    r'^Downloading .*$',
    r'^SAVED_TO=.*$',
    r'^SUMMARY_SAVED_TO=.*$',
    r'^===+.*$',
    r'^---+$',
]
lines = []
for line in text.splitlines():
    s = line.strip()
    if not s:
        lines.append('')
        continue
    if any(re.match(p, s, flags=re.I) for p in bad_patterns):
        continue
    # skip lines that are basically metrics/noise
    if re.match(r'^[\d.]+\s*(tok/s|tokens-per-sec|GB)\b', s, flags=re.I):
        continue
    if re.match(r'^(Time|Elapsed|Memory|Tokens)\b.*:\s*[\d.]+', s, flags=re.I):
        continue
    lines.append(line)

text = '\n'.join(lines)

# If mlx output contains channel separator, keep assistant side
for marker in ['<channel|>', 'assistant\n']:
    if marker in text:
        text = text.split(marker, 1)[-1]

# remove markdown/code fence clutter for voice
text = text.replace('```', ' ')
text = re.sub(r'`([^`]+)`', r'\1', text)
text = re.sub(r'\*\*([^*]+)\*\*', r'\1', text)
text = re.sub(r'__([^_]+)__', r'\1', text)
text = re.sub(r'\*([^*]+)\*', r'\1', text)
text = re.sub(r'_([^_]+)_', r'\1', text)

# collapse excessive whitespace
text = re.sub(r'\n{3,}', '\n\n', text).strip()

print(text)
