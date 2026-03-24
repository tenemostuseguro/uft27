#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash scripts/codex_force_text_snapshot.sh [target_branch] [remote_name]
# Example:
#   bash scripts/codex_force_text_snapshot.sh work origin

CURRENT_BRANCH="$(git branch --show-current)"
if [[ -z "$CURRENT_BRANCH" ]]; then
  echo "ERROR: Detached HEAD detected. Checkout a branch first." >&2
  exit 1
fi

TARGET_BRANCH="${1:-$CURRENT_BRANCH}"
REMOTE_NAME="${2:-origin}"
TMP_BRANCH="codex-text-snapshot-tmp"

if [[ "$TARGET_BRANCH" =~ ^(main|master)$ ]] && [[ "${ALLOW_MAIN:-0}" != "1" ]]; then
  echo "ERROR: Refusing to rewrite protected branch '$TARGET_BRANCH'." >&2
  echo "If you really want this, run with ALLOW_MAIN=1." >&2
  exit 1
fi

# Ensure clean working tree
if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: Working tree is not clean. Commit or stash changes first." >&2
  exit 1
fi

# Validate text-only policy before snapshot
bash scripts/check_binary_history.sh 7ab7ae8 HEAD
python3 scripts/check_nontext_tracked_files.py

# Build orphan snapshot
if git show-ref --verify --quiet "refs/heads/${TMP_BRANCH}"; then
  git branch -D "$TMP_BRANCH"
fi

git checkout --orphan "$TMP_BRANCH"
git rm -rf . >/dev/null 2>&1 || true
git checkout "$CURRENT_BRANCH" -- .
git add -A
git commit -m "Codex text-only snapshot commit"

# Move target branch to snapshot tip
new_commit="$(git rev-parse --short HEAD)"
git branch -f "$TARGET_BRANCH" "$TMP_BRANCH"
git checkout "$TARGET_BRANCH"
git branch -D "$TMP_BRANCH"

echo "OK: $TARGET_BRANCH now points to text-only snapshot commit $new_commit"
echo "Run: git push --force-with-lease $REMOTE_NAME $TARGET_BRANCH"
