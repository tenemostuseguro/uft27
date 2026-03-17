#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Uso: $0 <base_commit> <branch_name> <remote_name>"
  echo "Ejemplo: $0 7ab7ae8 work origin"
  exit 1
fi

BASE_COMMIT="$1"
BRANCH_NAME="$2"
REMOTE_NAME="$3"
TMP_BRANCH="clean-no-binary-tmp"

git checkout -b "$TMP_BRANCH" "$BASE_COMMIT"
git checkout "$BRANCH_NAME" -- .
git add -A
git commit -m "Rebuild branch without tracked image/binary history"
new_commit="$(git rev-parse --short HEAD)"

git checkout "$TMP_BRANCH"
git branch -f "$BRANCH_NAME" "$TMP_BRANCH"
git checkout "$BRANCH_NAME"
git branch -D "$TMP_BRANCH"

echo "Rama reconstruida en commit $new_commit"
echo "Ahora ejecuta: git push --force-with-lease $REMOTE_NAME $BRANCH_NAME"

