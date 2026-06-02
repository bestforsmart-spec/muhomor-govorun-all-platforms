#!/usr/bin/env python3
import re, sys
text = sys.stdin.read()
# remove metrics/log noise if pasted accidentally
bad_patterns = [
    r'^Prompt:\s*\d+\s+tokens.*$',
    r'^Generation:\s*\d+\s+tokens.*$',
    r'^Peak memory:\s*.*$',
    r'^Throughput:.*$',
    r'^SAVED_TO=.*$',
    r'^SUMMARY_SAVED_TO=.*$',
]
lines=[]
for line in text.splitlines():
    s=line.strip()
    if any(re.match(p,s,re.I) for p in bad_patterns):
        continue
    if re.match(r'^[\d.]+\s*(tok/s|tokens-per-sec|GB)\b', s, re.I):
        continue
    lines.append(line)
text='\n'.join(lines)
for marker in ['<channel|>', 'assistant\n']:
    if marker in text:
        text=text.split(marker,1)[-1]
text=text.replace('```',' ')
text=re.sub(r'`([^`]+)`', r'\1', text)
text=re.sub(r'\*\*([^*]+)\*\*', r'\1', text)
text=re.sub(r'__([^_]+)__', r'\1', text)
text=re.sub(r'\*([^*]+)\*', r'\1', text)
text=re.sub(r'_([^_]+)_', r'\1', text)
text=re.sub(r'https?://\S+', 'ссылка', text)
text=re.sub(r'\n{3,}', '\n\n', text)
text=text.strip()
print(text)
