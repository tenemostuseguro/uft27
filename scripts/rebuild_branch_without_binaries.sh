#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Uso: $0 <base_commit> [branch_name] [remote_name]"
  echo "Ejemplo: $0 7ab7ae8 work origin"
  exit 1
fi

BASE_COMMIT="$1"
CURRENT_BRANCH="$(git branch --show-current)"
if [[ -z "$CURRENT_BRANCH" ]]; then
  echo "ERROR: HEAD detached. Cambiá a una rama antes de continuar." >&2
  exit 1
fi

BRANCH_NAME="${2:-$CURRENT_BRANCH}"
REMOTE_NAME="${3:-origin}"
TMP_BRANCH="clean-no-binary-tmp"

if [[ "$BRANCH_NAME" =~ ^(main|master)$ ]] && [[ "${ALLOW_MAIN:-0}" != "1" ]]; then
  echo "ERROR: Se bloquea reescritura de rama protegida '$BRANCH_NAME'." >&2
  echo "Si realmente querés hacerlo, ejecutá con ALLOW_MAIN=1." >&2
  exit 1
fi

if git show-ref --verify --quiet "refs/heads/${TMP_BRANCH}"; then
  git branch -D "$TMP_BRANCH"
fi

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
