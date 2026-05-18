#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "install-git-hooks.sh: $*" >&2
  exit 1
}

command -v git >/dev/null 2>&1 || fail "git is required"
command -v gitleaks >/dev/null 2>&1 || fail "gitleaks is required: https://github.com/gitleaks/gitleaks"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || fail "run inside a git checkout"
cd "$repo_root"

[ -d .githooks ] || fail "missing .githooks directory"
[ -f .githooks/pre-commit ] || fail "missing .githooks/pre-commit"
[ -f .githooks/pre-push ] || fail "missing .githooks/pre-push"

chmod +x .githooks/pre-commit .githooks/pre-push
git config core.hooksPath .githooks

echo "Installed local git hooks from .githooks"
echo "Hooks run Gitleaks before commit and push."
echo "Use SKIP_GITLEAKS=1 only for an intentional emergency bypass."
