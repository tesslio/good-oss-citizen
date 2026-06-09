#!/usr/bin/env bash
# Create the install-gate feature branch from origin's default branch, so the
# scaffold lands on top of the canonical base regardless of which ref the
# caller happened to have checked out. Call after preflight passes and before
# scaffold.
#
# Determinism per rules/script-delegation.md: the base is resolved from the
# remote (origin/HEAD, set via `git remote set-head --auto` when unknown), not
# from the caller's current HEAD.
#
# Idempotent: if already on the feature branch, emits {"state":"already-on-branch"}
# and exits 0 instead of failing a second `checkout -b`.
#
# Usage: branch.sh
# Out:   one JSON object on stdout: {"state":"created|already-on-branch","branch":"...","base":"..."}
# Exit:  0 on success (including no-op); non-zero with a stderr diagnostic on failure

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "error: not inside a git worktree — run from within the consumer repo" >&2
  exit 1
}
cd "$repo_root"

BRANCH="feat/add-good-oss-citizen-gate"

main() {
  local current
  current=$(git rev-parse --abbrev-ref HEAD)
  if [[ "$current" == "$BRANCH" ]]; then
    printf '{"state":"already-on-branch","branch":"%s","base":"origin/HEAD"}\n' "$BRANCH"
    return 0
  fi

  # Resolve origin's default branch. Prefer the locally recorded origin/HEAD;
  # if it isn't set, ask the remote to set it (one network call).
  local default
  default=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)
  if [[ -z "$default" ]]; then
    git remote set-head origin --auto >/dev/null 2>&1 || true
    default=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)
  fi
  if [[ -z "$default" ]]; then
    echo "error: could not determine origin's default branch — run 'git remote set-head origin --auto' and re-try (check that origin is reachable)" >&2
    exit 1
  fi

  if ! git fetch origin "$default" >&2; then
    echo "error: 'git fetch origin ${default}' failed — check network/auth before re-running" >&2
    exit 1
  fi

  if ! git checkout -b "$BRANCH" "origin/${default}" >&2; then
    echo "error: could not create '${BRANCH}' from 'origin/${default}' — a local branch may already exist; delete it with 'git branch -D ${BRANCH}' or re-run preflight" >&2
    exit 1
  fi

  printf '{"state":"created","branch":"%s","base":"origin/%s"}\n' "$BRANCH" "$default"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
