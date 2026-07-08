#!/usr/bin/env bash
# Stage the files the install-gate scaffold produces and commit them with
# the canonical message. Call after scaffold.sh has succeeded and before
# push.sh.
#
# Always staged: the gate workflow, the vendored detector, and tessl.json.
# The PR template is staged ONLY when scaffold created it (it is byte-identical
# to the installed template) — never when an existing maintainer-owned template
# was left in place.
#
# Idempotent per rules/file-hygiene.md: if nothing is staged because the
# working tree already matches a prior successful run, the script emits
# {"state": "no-op", ...} with exit 0 instead of failing the way
# `git commit` would.
#
# Usage: commit.sh
# Out:   one JSON object on stdout: {"state": "committed|no-op", "commit": "<sha>"}
# Exit:  0 on success (including no-op); non-zero with stderr diagnostic on failure

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "error: not inside a git worktree — run from within the consumer repo" >&2
  exit 1
}
cd "$repo_root"

BRANCH="feat/add-good-oss-citizen-gate"
COMMIT_MSG="ci(gate): add good-oss-citizen contribution gate"

TILE_ROOT=".tessl/plugins/tessl-labs/good-oss-citizen"
PRTPL_SRC="${TILE_ROOT}/skills/install-gate/templates/PULL_REQUEST_TEMPLATE.md"
PRTPL_DST=".github/PULL_REQUEST_TEMPLATE.md"

REQUIRED=(
  .github/workflows/contribution-gate.yml
  .github/scripts/check_contribution_declaration.py
  tessl.json
)

main() {
  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  if [[ "$current_branch" != "$BRANCH" ]]; then
    echo "error: expected to be on '${BRANCH}' but current branch is '${current_branch}' — run 'git checkout -b ${BRANCH}' first" >&2
    exit 1
  fi

  local missing=()
  for f in "${REQUIRED[@]}"; do
    [[ -e "$f" ]] || missing+=("$f")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "error: scaffold incomplete — expected files missing: ${missing[*]} — run scaffold.sh first" >&2
    exit 1
  fi

  local files=("${REQUIRED[@]}")
  # Stage the PR template only if scaffold wrote it (byte-identical to source).
  if [[ -f "$PRTPL_DST" ]] && cmp -s "$PRTPL_DST" "$PRTPL_SRC"; then
    files+=("$PRTPL_DST")
  fi

  git add "${files[@]}"

  # Scope both the no-op check and the commit to exactly the gate files via
  # pathspec, so any unrelated changes the consumer had staged in the index are
  # never folded into the gate-install commit (rules/commit-conventions.md
  # one-logical-change).
  if git diff --cached --quiet -- "${files[@]}"; then
    printf '{"state": "no-op", "commit": "%s"}\n' "$(git rev-parse HEAD)"
    return 0
  fi

  if ! git commit -m "$COMMIT_MSG" -- "${files[@]}" >&2; then
    echo "error: 'git commit' failed — if a pre-commit hook rejected the change, fix the hook's finding and re-run (do NOT add --no-verify)" >&2
    exit 1
  fi

  printf '{"state": "committed", "commit": "%s"}\n' "$(git rev-parse HEAD)"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
