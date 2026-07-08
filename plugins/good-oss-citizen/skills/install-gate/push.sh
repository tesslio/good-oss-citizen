#!/usr/bin/env bash
# Push the install-gate feature branch to origin. Call AFTER commit.sh has
# produced the commit.
#
# Idempotent per rules/file-hygiene.md: if origin/feat/add-good-oss-citizen-gate
# already matches the local HEAD, the script emits {"state": "up-to-date", ...}
# with exit 0 instead of letting a redundant push produce noise.
#
# Usage: push.sh
# Out:   one JSON object on stdout: {"state": "pushed|up-to-date", "remote_ref": "origin/<branch>"}
# Exit:  0 on success (including up-to-date); non-zero with stderr diagnostic on failure

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "error: not inside a git worktree — run from within the consumer repo" >&2
  exit 1
}
cd "$repo_root"

BRANCH="feat/add-good-oss-citizen-gate"

main() {
  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  if [[ "$current_branch" != "$BRANCH" ]]; then
    echo "error: expected to be on '${BRANCH}' but current branch is '${current_branch}'" >&2
    exit 1
  fi

  local local_sha remote_sha
  local_sha=$(git rev-parse HEAD)
  remote_sha=$(git ls-remote --heads origin "$BRANCH" 2>/dev/null | awk '{print $1}' || echo "")
  if [[ -n "$remote_sha" && "$remote_sha" == "$local_sha" ]]; then
    printf '{"state": "up-to-date", "remote_ref": "origin/%s"}\n' "$BRANCH"
    return 0
  fi

  if ! git push -u origin "$BRANCH" >&2; then
    echo "error: 'git push' failed — the commit stands locally; inspect the remote and retry" >&2
    exit 1
  fi

  printf '{"state": "pushed", "remote_ref": "origin/%s"}\n' "$BRANCH"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
