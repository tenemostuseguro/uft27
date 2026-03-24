#!/usr/bin/env bash
set -euo pipefail

BASE_COMMIT="${1:-7ab7ae8}"
HEAD_REF="${2:-HEAD}"

echo "Checking history for binary-like file changes from ${BASE_COMMIT}..${HEAD_REF}"

if ! git rev-parse --verify "$BASE_COMMIT" >/dev/null 2>&1; then
  echo "Base commit not found: $BASE_COMMIT" >&2
  exit 2
fi

# Detect git numstat binary markers (- -)
if git diff --numstat "${BASE_COMMIT}..${HEAD_REF}" | awk '$1=="-" || $2=="-" {print}' | grep -q .; then
  echo "ERROR: Found binary changes by git numstat marker (- -):" >&2
  git diff --numstat "${BASE_COMMIT}..${HEAD_REF}" | awk '$1=="-" || $2=="-" {print}' >&2
  exit 1
fi

# Detect NUL bytes in reachable blobs changed in range
python - "$BASE_COMMIT" "$HEAD_REF" <<'PY'
import subprocess, sys
base, head = sys.argv[1], sys.argv[2]
commits = subprocess.check_output(['git', 'rev-list', f'{base}..{head}'], text=True).splitlines()
for c in commits:
    files = subprocess.check_output(['git','diff-tree','--no-commit-id','--name-only','-r',c], text=True).splitlines()
    for f in files:
        try:
            data = subprocess.check_output(['git','show',f'{c}:{f}'])
        except subprocess.CalledProcessError:
            continue
        if b'\x00' in data:
            print(f'ERROR: NUL-byte blob detected in commit {c} file {f}', file=sys.stderr)
            sys.exit(1)
print('OK: no binary markers detected in range')
PY
