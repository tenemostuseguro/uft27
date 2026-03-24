#!/usr/bin/env python3
import subprocess
import sys

# Extensions that are expected text in this repo
TEXT_EXTS = {
    '.gd', '.tscn', '.godot', '.md', '.sql', '.php', '.sh', '.py', '.html', '.json', '.yml', '.yaml', '.txt', '.gitignore', '.gitattributes'
}

TEXT_EXACT = {'.gitkeep'}

files = subprocess.check_output(['git', 'ls-files'], text=True).splitlines()
errors = []

for f in files:
    # Skip anything without extension only if explicitly known textual paths
    lower = f.lower()
    ok_ext = any(lower.endswith(ext) for ext in TEXT_EXTS) or any(lower.endswith(exact) for exact in TEXT_EXACT)
    if not ok_ext:
        errors.append((f, 'unsupported extension for text-only policy'))
        continue

    data = subprocess.check_output(['git', 'show', f'HEAD:{f}'])
    if b'\x00' in data:
        errors.append((f, 'contains NUL byte'))
        continue

    try:
        data.decode('utf-8')
    except UnicodeDecodeError:
        errors.append((f, 'not valid UTF-8'))

if errors:
    print('ERROR: text-only policy violations found:', file=sys.stderr)
    for f, reason in errors:
        print(f' - {f}: {reason}', file=sys.stderr)
    sys.exit(1)

print(f'OK: {len(files)} tracked files pass text-only checks')
