#!/usr/bin/env bash
set -euo pipefail

BASE_COMMIT="${1:-7ab7ae8}"
HEAD_REF="${2:-HEAD}"

echo "== Numstat check =="
git diff --numstat "${BASE_COMMIT}..${HEAD_REF}" | awk '$1=="-" || $2=="-" {print}' || true

echo "== Git attributes check (tracked files) =="
while IFS= read -r f; do
  attrs=$(git check-attr -a -- "$f" | tr '\n' '; ')
  echo "$f :: $attrs"
done < <(git ls-files)

echo "== NUL-byte scan in changed files =="
python3 - "$BASE_COMMIT" "$HEAD_REF" <<'PY'
import subprocess, sys
base, head = sys.argv[1], sys.argv[2]
commits = subprocess.check_output(['git','rev-list',f'{base}..{head}'], text=True).splitlines()
found = 0
for c in commits:
    files = subprocess.check_output(['git','diff-tree','--no-commit-id','--name-only','-r',c], text=True).splitlines()
    for f in files:
        try:
            data = subprocess.check_output(['git','show',f'{c}:{f}'])
        except subprocess.CalledProcessError:
            continue
        if b'\x00' in data:
            found += 1
            print(f'NUL found: {c} {f}')
print('nul_count', found)
PY
