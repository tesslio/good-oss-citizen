#!/usr/bin/env bash
# Scaffold the good-oss-citizen contribution gate into a consumer repo:
#   - .github/workflows/contribution-gate.yml      (the PR-side gate)
#   - .github/scripts/check_contribution_declaration.py  (vendored detector)
#   - .github/PULL_REQUEST_TEMPLATE.md             (only if the repo has none)
#   - tessl.json                                   (ensure the dependency entry)
# Call after creating the feature branch and before committing.
#
# Idempotent per rules/file-hygiene.md: re-running is safe — mkdir -p no-ops,
# cp rewrites the workflow/script from the templates, the PR template is only
# written when the repo lacks one, and the tessl.json dependency is added only
# when missing (an existing pin is never overwritten). The overwrite-safety
# guard for the workflow/script lives in the install-gate skill, which halts
# before this script runs if the repo already has a gate.
#
# Usage: scaffold.sh
# Out:   one JSON object on stdout describing what was written, the tessl.json
#        state, and any warnings (e.g. an existing PR template the maintainer
#        must extend by hand).
# Exit:  0 on success; non-zero with a stderr diagnostic on failure

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

  mkdir -p "$(dirname "$WORKFLOW_DST")" "$(dirname "$SCRIPT_DST")"
  cp "$WORKFLOW_SRC" "$WORKFLOW_DST"
  cp "$SCRIPT_SRC" "$SCRIPT_DST"

  # PR template: only add one if the repo has none anywhere GitHub looks. A
  # PR-template directory (.github/PULL_REQUEST_TEMPLATE/) also counts as
  # "has templates" and is left untouched.
  local prtpl_state prtpl_path existing=""
  for cand in "${PRTPL_CANDIDATES[@]}"; do
    if [[ -f "$cand" ]]; then existing="$cand"; break; fi
  done
  if [[ -z "$existing" && -d ".github/PULL_REQUEST_TEMPLATE" ]]; then
    existing=".github/PULL_REQUEST_TEMPLATE/"
  fi
  if [[ -n "$existing" ]]; then
    prtpl_state="skipped-existing"
    prtpl_path="$existing"
  else
    cp "$PRTPL_SRC" "$PRTPL_DST"
    prtpl_state="created"
    prtpl_path="$PRTPL_DST"
  fi

  WORKFLOW_DST="$WORKFLOW_DST" SCRIPT_DST="$SCRIPT_DST" \
  PRTPL_STATE="$prtpl_state" PRTPL_PATH="$prtpl_path" \
  TESSL_JSON="$TESSL_JSON" DEP_NAME="$DEP_NAME" VERSION="$version" \
  python3 <<'PY'
import json, os

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
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
