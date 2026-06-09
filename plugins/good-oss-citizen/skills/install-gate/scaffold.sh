#!/usr/bin/env bash
# Scaffold the good-oss-citizen contribution gate into a consumer repo:
#   - .github/workflows/contribution-gate.yml      (the PR-side gate)
#   - .github/scripts/check_contribution_declaration.py  (vendored detector)
#   - .github/PULL_REQUEST_TEMPLATE.md             (only if the repo has none)
#   - tessl.json                                   (ensure the dependency entry)
# Call after creating the feature branch and before committing.
#
# Atomic per rules/file-hygiene.md: either every artifact lands or none do.
# All checks that can fail (template presence, version read, tessl.json
# parseability) run BEFORE any mutation, and a rollback trap removes every
# file this run created and restores tessl.json from a snapshot if any later
# step fails — so a failed run never leaves a partial install that the skill's
# overwrite guard would then refuse to re-run over.
#
# Idempotent: re-running is safe — files this run already produced match the
# templates, and the tessl.json dependency is added only when missing (an
# existing pin is never overwritten).
#
# Usage: scaffold.sh
# Out:   one JSON object on stdout describing what was written, the tessl.json
#        state, and any warnings (e.g. an existing PR template the maintainer
#        must extend by hand).
# Exit:  0 on success; non-zero with a stderr diagnostic on failure (rolled back)

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "error: not inside a git worktree — run from within the consumer repo" >&2
  exit 1
}
cd "$repo_root"

TILE_ROOT=".tessl/plugins/tessl-labs/good-oss-citizen"
TEMPLATE_DIR="${TILE_ROOT}/skills/install-gate/templates"
TILE_JSON="${TILE_ROOT}/.tessl-plugin/plugin.json"

WORKFLOW_SRC="${TEMPLATE_DIR}/contribution-gate.yml"
SCRIPT_SRC="${TEMPLATE_DIR}/check_contribution_declaration.py"
PRTPL_SRC="${TEMPLATE_DIR}/PULL_REQUEST_TEMPLATE.md"

WORKFLOW_DST=".github/workflows/contribution-gate.yml"
SCRIPT_DST=".github/scripts/check_contribution_declaration.py"
PRTPL_DST=".github/PULL_REQUEST_TEMPLATE.md"
TESSL_JSON="tessl.json"
DEP_NAME="tessl-labs/good-oss-citizen"

# Known locations GitHub recognizes for a single PR template; if any exists we
# must not add a competing one.
PRTPL_CANDIDATES=(
  ".github/PULL_REQUEST_TEMPLATE.md"
  ".github/pull_request_template.md"
  "PULL_REQUEST_TEMPLATE.md"
  "pull_request_template.md"
  "docs/PULL_REQUEST_TEMPLATE.md"
  "docs/pull_request_template.md"
)

main() {
  # ---- Pre-mutation validation (nothing on disk changes in this block) ----
  for src in "$WORKFLOW_SRC" "$SCRIPT_SRC" "$PRTPL_SRC"; do
    if [[ ! -f "$src" ]]; then
      echo "error: template not found at ${src} — run 'tessl install tessl-labs/good-oss-citizen' first" >&2
      exit 1
    fi
  done

  local version
  version=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['version'])" "$TILE_JSON" 2>/dev/null) || {
    echo "error: could not read version from ${TILE_JSON} — the installed plugin looks broken; re-run 'tessl install tessl-labs/good-oss-citizen'" >&2
    exit 1
  }

  # Fail early on a malformed existing tessl.json, before any file is touched.
  if [[ -f "$TESSL_JSON" ]]; then
    python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$TESSL_JSON" 2>/dev/null || {
      echo "error: ${TESSL_JSON} is not valid JSON — fix it and re-run (scaffold made no changes)" >&2
      exit 1
    }
  fi

  # Decide the PR-template outcome without writing anything yet.
  local existing=""
  for cand in "${PRTPL_CANDIDATES[@]}"; do
    if [[ -f "$cand" ]]; then existing="$cand"; break; fi
  done
  if [[ -z "$existing" && -d ".github/PULL_REQUEST_TEMPLATE" ]]; then
    existing=".github/PULL_REQUEST_TEMPLATE/"
  fi

  # ---- Record prior state so a mid-run failure rolls back cleanly ----
  local wf_existed=0 sc_existed=0 prtpl_created=0 tessl_existed=0 tessl_snapshot=""
  [[ -f "$WORKFLOW_DST" ]] && wf_existed=1
  [[ -f "$SCRIPT_DST" ]] && sc_existed=1
  if [[ -f "$TESSL_JSON" ]]; then
    tessl_existed=1
    tessl_snapshot=$(mktemp -t tessl-json.XXXXXX)
    cp "$TESSL_JSON" "$tessl_snapshot"
  fi

  rollback() {
    trap - ERR
    # A cleanup handler must run to completion even if one step fails, so
    # disable errexit for the rest of this function.
    set +e
    [[ $wf_existed -eq 0 ]] && rm -f "$WORKFLOW_DST"
    [[ $sc_existed -eq 0 ]] && rm -f "$SCRIPT_DST"
    [[ $prtpl_created -eq 1 ]] && rm -f "$PRTPL_DST"
    if [[ $tessl_existed -eq 1 && -n "$tessl_snapshot" ]]; then
      cp "$tessl_snapshot" "$TESSL_JSON"
    elif [[ $tessl_existed -eq 0 ]]; then
      rm -f "$TESSL_JSON"
    fi
    [[ -n "$tessl_snapshot" ]] && rm -f "$tessl_snapshot"
    echo "error: scaffold failed — rolled back every file this run created and restored ${TESSL_JSON}; fix the cause and re-run" >&2
  }
  trap rollback ERR

  # ---- Mutations (any failure here triggers rollback) ----
  mkdir -p "$(dirname "$WORKFLOW_DST")" "$(dirname "$SCRIPT_DST")"
  cp "$WORKFLOW_SRC" "$WORKFLOW_DST"
  cp "$SCRIPT_SRC" "$SCRIPT_DST"

  local prtpl_state prtpl_path
  if [[ -n "$existing" ]]; then
    prtpl_state="skipped-existing"
    prtpl_path="$existing"
  else
    cp "$PRTPL_SRC" "$PRTPL_DST"
    prtpl_created=1
    prtpl_state="created"
    prtpl_path="$PRTPL_DST"
  fi

  WORKFLOW_DST="$WORKFLOW_DST" SCRIPT_DST="$SCRIPT_DST" \
  PRTPL_STATE="$prtpl_state" PRTPL_PATH="$prtpl_path" \
  TESSL_JSON="$TESSL_JSON" DEP_NAME="$DEP_NAME" VERSION="$version" \
  python3 <<'PY'
import json, os, sys

tessl_json = os.environ["TESSL_JSON"]
dep = os.environ["DEP_NAME"]
version = os.environ["VERSION"]

if not os.path.exists(tessl_json):
    repo_name = os.path.basename(os.getcwd())
    doc = {"name": repo_name, "dependencies": {dep: {"version": version}}}
    tessl_state = "created"
else:
    with open(tessl_json, encoding="utf-8") as handle:
        doc = json.load(handle)
    deps = doc.setdefault("dependencies", {})
    if dep in deps:
        tessl_state = "present"
    else:
        deps[dep] = {"version": version}
        tessl_state = "updated"

if tessl_state != "present":
    with open(tessl_json, "w", encoding="utf-8") as handle:
        json.dump(doc, handle, indent=2)
        handle.write("\n")

warnings = []
if os.environ["PRTPL_STATE"] == "skipped-existing":
    warnings.append(
        "This repo already has a pull-request template at "
        f"{os.environ['PRTPL_PATH']} — the gate did NOT modify it. Add a "
        "contribution declaration to it by hand: a '- [ ] written without AI "
        "assistance' checkbox and/or an 'AI Disclosure' section. Without one "
        "of those, every PR using that template will fail the gate."
    )

print(json.dumps({
    "workflow": os.environ["WORKFLOW_DST"],
    "script": os.environ["SCRIPT_DST"],
    "pr_template": {"path": os.environ["PRTPL_PATH"], "state": os.environ["PRTPL_STATE"]},
    "tessl_json": {"path": tessl_json, "state": tessl_state, "version": version},
    "warnings": warnings,
}))
PY

  # Success — disarm rollback and discard the snapshot. Use an if-block, not
  # `[[ ]] && rm`: when there is no snapshot the && list returns non-zero, and
  # as the function's last statement under `set -e` that would exit non-zero
  # despite a fully successful scaffold.
  trap - ERR
  if [[ -n "$tessl_snapshot" ]]; then rm -f "$tessl_snapshot"; fi
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
