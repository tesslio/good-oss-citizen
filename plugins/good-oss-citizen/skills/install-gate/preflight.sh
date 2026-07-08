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

# Serialize the accumulators to JSON in pure bash. preflight must emit its
# envelope even when python3 is absent — python3 is one of the very
# preconditions this script checks, so it cannot be the tool that reports its
# own absence (rules/script-delegation.md: a script must self-emit its
# failure envelope).
json_escape() { local s=$1; s=${s//\\/\\\\}; s=${s//\"/\\\"}; printf '%s' "$s"; }

json_array() {  # $1 = tab-delimited "check<TAB>reason" lines
  local blob=$1 out="" sep="" line check reason
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    check=${line%%$'\t'*}
    reason=${line#*$'\t'}
    out+="${sep}{\"check\":\"$(json_escape "$check")\",\"reason\":\"$(json_escape "$reason")\"}"
    sep=","
  done <<< "$blob"
  printf '[%s]' "$out"
}

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
  # `git ls-remote --exit-code` distinguishes three outcomes: 0 = the ref
  # exists, 2 = the remote answered and has no such ref (the good case), and
  # anything else = a transport/auth failure where we CANNOT confirm the
  # remote's state. Treat that last case as a preflight failure rather than
  # silently assuming the branch is absent and letting a later push surprise
  # the user.
  local rc=0
  git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1 || rc=$?
  if [[ $rc -eq 0 ]]; then
    push_failure "branch-not-remote" "Remote branch 'origin/${BRANCH}' already exists — delete with 'git push origin --delete ${BRANCH}' or rename before re-running"
  elif [[ $rc -ne 2 ]]; then
    push_failure "remote-reachable" "Could not reach 'origin' to check for an existing branch (git ls-remote exit ${rc}) — verify network and auth (e.g. 'gh auth status', 'git remote -v') before re-running"
  fi
}

# tessl.json is the one install target that can already exist and is rewritten
# by scaffold.sh. If it carries uncommitted edits, the gate-install commit
# would bundle them with the dependency change, breaking the one-logical-change
# rule (rules/commit-conventions.md). Refuse until it is clean.
check_target_clean() {
  [[ -f tessl.json ]] || return 0
  # `git status --porcelain` catches untracked (??), modified, and staged
  # states alike — a pre-existing tessl.json in any of them would be folded
  # into the gate-install commit by scaffold + commit. A plain `git diff`
  # would miss the untracked case.
  if [[ -n "$(git status --porcelain -- tessl.json 2>/dev/null)" ]]; then
    push_failure "tessl-json-clean" "tessl.json exists but is not committed-clean (untracked or has uncommitted changes) — commit or stash it before installing the gate so it isn't bundled into the gate-install commit"
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
    check_target_clean
    if git remote get-url origin >/dev/null 2>&1; then
      check_branch_not_remote
    fi
  fi

  local rc=0 ok="true"
  if [[ -n "$failures" ]]; then rc=1; ok="false"; fi

  printf '{"ok":%s,"failures":%s,"warnings":%s}\n' \
    "$ok" "$(json_array "$failures")" "$(json_array "$warnings")"

  if [[ $rc -ne 0 ]]; then
    echo "preflight: precondition(s) failed — see the 'failures' array in stdout for recovery commands" >&2
  fi
  exit "$rc"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
