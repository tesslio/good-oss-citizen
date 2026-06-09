#!/usr/bin/env bash
# Run all install-gate preconditions and report them as one JSON result.
# The skill invokes this before any mutation so every preflight failure is
# surfaced together, not one-at-a-time. Checks cover: git worktree, python3,
# GitHub CLI installation + auth, installed-plugin templates, origin remote,
# and local + remote branch clear.
#
# Usage: preflight.sh
# Out:   one JSON object on stdout:
#          {"ok": bool,
#           "failures": [{"check": "<name>", "reason": "<human text>"}, ...],
#           "warnings": [{"check": "<name>", "reason": "<human text>"}, ...]}
#        When ok is false, each failure includes a concrete recovery command
#        where applicable. Warnings are informational only — they never set
#        ok to false or change the exit code.
# Exit:  0 if ok is true; 1 if any check fails

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [[ -n "$repo_root" ]]; then
  cd "$repo_root"
fi

BRANCH="feat/add-good-oss-citizen-gate"
TILE_ROOT=".tessl/plugins/tessl-labs/good-oss-citizen"
TEMPLATE_DIR="${TILE_ROOT}/skills/install-gate/templates"
TEMPLATES=(
  "${TEMPLATE_DIR}/contribution-gate.yml"
  "${TEMPLATE_DIR}/check_contribution_declaration.py"
  "${TEMPLATE_DIR}/PULL_REQUEST_TEMPLATE.md"
)

# Tab-delimited "check\treason" lines; serialized to JSON by python3 at the end.
failures=""
warnings=""

push_failure() { failures+="$1	$2"$'\n'; }

check_in_git_worktree() {
  git rev-parse --git-dir >/dev/null 2>&1 || \
    push_failure "in-git-worktree" "Not inside a git worktree — run the skill from the root of the consumer repo's git checkout"
}

check_python3() {
  command -v python3 >/dev/null 2>&1 || \
    push_failure "python3" "python3 not found on PATH — install Python 3 (the gate's detection script and this skill's scaffolding both need it)"
}

check_origin_remote() {
  git remote get-url origin >/dev/null 2>&1 || \
    push_failure "origin-remote" "No git remote named 'origin' — add one with 'git remote add origin <url>' before re-running (the push step assumes origin exists)"
}

check_gh_installed() {
  command -v gh >/dev/null 2>&1 || \
    push_failure "gh-installed" "GitHub CLI not found on PATH — install from https://cli.github.com/ (needed to open the install PR)"
}

check_gh_authenticated() {
  gh auth status >/dev/null 2>&1 || \
    push_failure "gh-authenticated" "GitHub CLI not authenticated — run 'gh auth login'"
}

check_templates_present() {
  local missing=()
  for t in "${TEMPLATES[@]}"; do
    [[ -f "$t" ]] || missing+=("$t")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    push_failure "templates-present" "Template(s) not found: ${missing[*]} — run 'tessl install tessl-labs/good-oss-citizen' first"
  fi
}

check_branch_not_local() {
  if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
    push_failure "branch-not-local" "Local branch '${BRANCH}' already exists — delete with 'git branch -D ${BRANCH}' or rename before re-running"
  fi
}

check_branch_not_remote() {
  if git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
    push_failure "branch-not-remote" "Remote branch 'origin/${BRANCH}' already exists — delete with 'git push origin --delete ${BRANCH}' or rename before re-running"
  fi
}

main() {
  check_in_git_worktree
  check_python3
  check_gh_installed
  if command -v gh >/dev/null 2>&1; then
    check_gh_authenticated
  fi
  check_templates_present
  if git rev-parse --git-dir >/dev/null 2>&1; then
    check_origin_remote
    check_branch_not_local
    if git remote get-url origin >/dev/null 2>&1; then
      check_branch_not_remote
    fi
  fi

  local rc=0
  [[ -n "$failures" ]] && rc=1

  FAILURES="$failures" WARNINGS="$warnings" python3 - <<'PY'
import json, os

def parse(blob):
    items = []
    for line in blob.splitlines():
        if not line.strip():
            continue
        check, _, reason = line.partition("\t")
        items.append({"check": check, "reason": reason})
    return items

failures = parse(os.environ.get("FAILURES", ""))
warnings = parse(os.environ.get("WARNINGS", ""))
print(json.dumps({
    "ok": len(failures) == 0,
    "failures": failures,
    "warnings": warnings,
}))
PY

  if [[ $rc -ne 0 ]]; then
    echo "preflight: precondition(s) failed — see the 'failures' array in stdout for recovery commands" >&2
  fi
  exit "$rc"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
