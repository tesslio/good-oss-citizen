#!/usr/bin/env bash
# GitHub API helper for good-oss-citizen tile.
#
# Output contract: every command prints exactly one JSON envelope on
# stdout, of shape:
#   {"command": <name>, "ok": <bool>, "data": <object|null>,
#    "warnings": [<str>, ...], "errors": [<str>, ...]}
# See ./_envelope.py for emit/fail and the shared fetch_json client.
#
# Usage:
#   github.sh <command> <owner/repo> [arg]
#
# See the help case at the bottom for the full command list.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PYTHONPATH="${SCRIPT_DIR}${PYTHONPATH:+:${PYTHONPATH}}"

COMMAND="${1:-}"
REPO="${2:-}"
ARG="${3:-}"
# Exported so the python heredocs (and the excepthook in _envelope.py)
# can label any failure envelope with the right command name.
export COMMAND

case "$COMMAND" in
    repo-scan)
        REPO="$REPO" python3 <<'PYEOF'
import os
from _envelope import emit, fail, fetch_json

REPO = os.environ["REPO"]
CMD = "repo-scan"

repo_meta = fetch_json(f"/repos/{REPO}")
if not repo_meta or "default_branch" not in repo_meta:
    fail(CMD, f"could not fetch repo metadata for {REPO}")

default_branch = repo_meta["default_branch"]
ref = fetch_json(f"/repos/{REPO}/git/refs/heads/{default_branch}")
if not ref or "object" not in ref:
    fail(CMD, f"could not resolve default branch {default_branch} for {REPO}")

sha = ref["object"]["sha"]
tree = fetch_json(f"/repos/{REPO}/git/trees/{sha}?recursive=1")
if not tree or "tree" not in tree:
    fail(CMD, f"could not fetch tree {sha} for {REPO}")

paths = {item["path"] for item in tree.get("tree", []) if item.get("type") == "blob"}

def categorize(targets):
    return {
        "found": [t for t in targets if t in paths],
        "missing": [t for t in targets if t not in paths],
    }

policy_files = categorize([
    "CONTRIBUTING.md", "AI_POLICY.md", "CODE_OF_CONDUCT.md",
    "SECURITY.md", "DCO", "LICENSE", "README.md",
])
agent_instructions = categorize([
    "AGENTS.md", "CLAUDE.md", ".cursorrules",
    ".github/copilot-instructions.md", "HOWTOAI.md", "PROMPTING.md",
])
conventions = categorize([
    ".editorconfig", ".prettierrc", "rustfmt.toml", ".clang-format",
    "pyproject.toml", ".pre-commit-config.yaml",
    "commitlint.config.js", "commitlint.config.cjs",
    ".golangci.yml", "Cargo.toml", "go.mod",
])
build_meta = categorize([
    "CHANGELOG.md", "CODEOWNERS", "DEVELOPMENT.md", "Makefile",
    "justfile", "Taskfile.yml",
])

pr_template_singles = [
    ".github/PULL_REQUEST_TEMPLATE.md", ".github/pull_request_template.md",
    "docs/PULL_REQUEST_TEMPLATE.md", "PULL_REQUEST_TEMPLATE.md",
]
pr_dir = sorted(p for p in paths if p.startswith(".github/PULL_REQUEST_TEMPLATE/"))
pr_templates_found = [p for p in pr_template_singles if p in paths] + pr_dir

# `.github/ISSUE_TEMPLATE/` is the directory layout (multi-template);
# `.github/ISSUE_TEMPLATE.md` is the single-file legacy form. Match the
# directory with a trailing slash so the legacy single file isn't
# double-counted.
issue_dir = sorted(p for p in paths if p.startswith(".github/ISSUE_TEMPLATE/"))
issue_legacy = [p for p in (".github/ISSUE_TEMPLATE.md", "ISSUE_TEMPLATE.md") if p in paths]
issue_templates_found = issue_dir + issue_legacy

emit(CMD, {
    "default_branch": default_branch,
    "policy_files": policy_files,
    "agent_instructions": agent_instructions,
    "conventions": conventions,
    "build_meta": build_meta,
    "pr_templates": {"found": pr_templates_found},
    "issue_templates": {"found": issue_templates_found},
    "test_fixtures": {
        "found": sorted(
            p for p in paths
            if "conftest.py" in p or "test_helper" in p or "testutil" in p
        )
    },
    "ci_workflows": {
        "found": sorted(p for p in paths if p.startswith(".github/workflows/"))
    },
})
PYEOF
        ;;

    issue)
        REPO="$REPO" ARG="$ARG" python3 <<'PYEOF'
import os
from _envelope import emit, fail, fetch_json

REPO = os.environ["REPO"]
ARG = os.environ["ARG"]
d = fetch_json(f"/repos/{REPO}/issues/{ARG}")
if not d or "number" not in d:
    fail("issue", f"could not fetch issue {ARG} from {REPO}")

emit("issue", {
    "number": d["number"],
    "title": d.get("title", ""),
    "state": d.get("state", ""),
    "labels": [l["name"] for l in d.get("labels", [])],
    "assignee": d["assignee"]["login"] if d.get("assignee") else None,
    "body": d.get("body") or "",
})
PYEOF
        ;;

    issue-comments|pr-comments)
        REPO="$REPO" ARG="$ARG" CMD="$COMMAND" python3 <<'PYEOF'
import os
from _envelope import emit, fail, fetch_json

REPO = os.environ["REPO"]
ARG = os.environ["ARG"]
CMD = os.environ["CMD"]
comments = fetch_json(f"/repos/{REPO}/issues/{ARG}/comments")
if comments is None:
    fail(CMD, f"could not fetch comments for {ARG} on {REPO}")

emit(CMD, {
    "comments": [
        {
            "user": c.get("user", {}).get("login", ""),
            "created_at": c.get("created_at", ""),
            "body": c.get("body", ""),
        }
        for c in comments
    ]
})
PYEOF
        ;;

    check-claim)
        REPO="$REPO" ARG="$ARG" python3 <<'PYEOF'
import os
from _envelope import emit, fail, fetch_json

REPO = os.environ["REPO"]
ARG = os.environ["ARG"]
comments = fetch_json(f"/repos/{REPO}/issues/{ARG}/comments")
if comments is None:
    fail("check-claim", f"could not fetch comments for {ARG} on {REPO}")

emit("check-claim", {
    "comments": [
        {
            "user": c.get("user", {}).get("login", ""),
            "created_at": c.get("created_at", ""),
            "body": c.get("body", ""),
        }
        for c in comments
    ]
}, warnings=[
    "DEPRECATED: use 'issue-comments' instead. The LLM should interpret whether any comment indicates a claim."
])
PYEOF
        ;;

    issues-open|issues-closed)
        REPO="$REPO" CMD="$COMMAND" python3 <<'PYEOF'
import os
from _envelope import emit, fail, fetch_json

REPO = os.environ["REPO"]
CMD = os.environ["CMD"]
state = "open" if CMD == "issues-open" else "closed"
issues = fetch_json(f"/repos/{REPO}/issues?state={state}&per_page=30")
if issues is None:
    fail(CMD, f"could not fetch {state} issues for {REPO}")

filtered = [i for i in issues if "pull_request" not in i]
emit(CMD, {
    "issues": [
        {
            "number": i["number"],
            "title": i.get("title", ""),
            "state": i.get("state", state),
            "labels": [l["name"] for l in i.get("labels", [])],
            "assignee": i["assignee"]["login"] if i.get("assignee") else None,
            "state_reason": i.get("state_reason"),
        }
        for i in filtered
    ]
})
PYEOF
        ;;

    prs-closed)
        REPO="$REPO" python3 <<'PYEOF'
import os
from _envelope import emit, fail, fetch_json

REPO = os.environ["REPO"]
prs = fetch_json(f"/repos/{REPO}/pulls?state=closed&per_page=30")
if prs is None:
    fail("prs-closed", f"could not fetch closed PRs for {REPO}")

emit("prs-closed", {
    "prs": [
        {
            "number": p["number"],
            "title": p.get("title", ""),
            "merged": bool(p.get("merged_at")),
        }
        for p in prs
    ]
})
PYEOF
        ;;

    pr-history)
        REPO="$REPO" python3 <<'PYEOF'
import os
from _envelope import emit, fail, fetch_json

REPO = os.environ["REPO"]
prs = fetch_json(f"/repos/{REPO}/pulls?state=closed&per_page=20")
if prs is None:
    fail("pr-history", f"could not fetch closed PRs for {REPO}")

out = []
warnings = []
for p in prs:
    merged = bool(p.get("merged_at"))
    entry = {
        "number": p["number"],
        "title": p.get("title", ""),
        "merged": merged,
        "comments": [],
        "comments_fetch_failed": False,
    }
    if not merged:
        comments = fetch_json(f"/repos/{REPO}/issues/{p['number']}/comments")
        if comments is None:
            entry["comments_fetch_failed"] = True
            warnings.append(
                f"could not fetch comments for PR #{p['number']} — "
                "this may hide rejection feedback"
            )
        else:
            entry["comments"] = [
                {
                    "user": c.get("user", {}).get("login", ""),
                    "body": (c.get("body", "") or "")[:500],
                }
                for c in comments
            ]
    out.append(entry)

emit("pr-history", {"prs": out}, warnings=warnings)
PYEOF
        ;;

    related-prs)
        REPO="$REPO" ARG="$ARG" python3 <<'PYEOF'
import os
from _envelope import emit, fail, fetch_json

REPO = os.environ["REPO"]
ISSUE_NUM = os.environ["ARG"]
prs = fetch_json(f"/repos/{REPO}/pulls?state=closed&per_page=20")
if prs is None:
    fail("related-prs", f"could not fetch closed PRs for {REPO}")

found = []
warnings = []
for p in prs:
    title = p.get("title") or ""
    body = p.get("body") or ""
    if (f"#{ISSUE_NUM}" in body
            or f"#{ISSUE_NUM}" in title
            or f"issue {ISSUE_NUM}" in body.lower()):
        entry = {
            "number": p["number"],
            "title": p.get("title", ""),
            "merged": bool(p.get("merged_at")),
            "comments": [],
            "comments_fetch_failed": False,
        }
        if not entry["merged"]:
            comments = fetch_json(f"/repos/{REPO}/issues/{p['number']}/comments")
            if comments is None:
                entry["comments_fetch_failed"] = True
                warnings.append(
                    f"could not fetch comments for PR #{p['number']} — "
                    "this may hide rejection feedback"
                )
            else:
                entry["comments"] = [
                    {
                        "user": c.get("user", {}).get("login", ""),
                        "body": (c.get("body", "") or "")[:500],
                    }
                    for c in comments
                ]
        found.append(entry)

emit("related-prs", {"issue_number": ISSUE_NUM, "prs": found}, warnings=warnings)
PYEOF
        ;;

    file)
        REPO="$REPO" ARG="$ARG" python3 <<'PYEOF'
import base64
import os
from _envelope import emit, fail, fetch_json

REPO = os.environ["REPO"]
PATH = os.environ["ARG"]
d = fetch_json(f"/repos/{REPO}/contents/{PATH}")
if not d or "content" not in d:
    fail("file", f"could not fetch {PATH} from {REPO}")

try:
    content = base64.b64decode(d["content"]).decode("utf-8")
except (ValueError, UnicodeDecodeError) as e:
    fail("file", f"could not decode {PATH}: {e}")

emit("file", {"path": PATH, "content": content})
PYEOF
        ;;

    commit-conventions)
        REPO="$REPO" python3 <<'PYEOF'
import os
import re
from _envelope import emit, fail, fetch_json

REPO = os.environ["REPO"]
prs = fetch_json(f"/repos/{REPO}/pulls?state=closed&per_page=10")
if prs is None:
    fail("commit-conventions", f"could not fetch closed PRs for {REPO}")

merged = [p for p in prs if p.get("merged_at")]
if not merged:
    emit("commit-conventions", {
        "sample_size": 0, "conventional": 0, "signed_off": 0,
        "format": None, "signed_off_required": False, "examples": [],
    }, warnings=["no merged PRs found in the most recent 10 closed PRs"])
    raise SystemExit(0)

CONVENTIONAL = re.compile(
    r"^(feat|fix|docs|chore|refactor|test|style|perf|ci|build|revert)(\(.+\))?:"
)

messages = []
conventional = 0
signed_off = 0
warnings = []
for p in merged[:5]:
    commits = fetch_json(f"/repos/{REPO}/pulls/{p['number']}/commits")
    if commits is None:
        warnings.append(
            f"could not fetch commits for PR #{p['number']} — "
            "convention sample may under-report"
        )
        continue
    for c in commits:
        msg = c.get("commit", {}).get("message", "") or ""
        if not msg:
            continue
        first = msg.split("\n", 1)[0]
        if first.startswith("Merge "):
            continue
        messages.append(first)
        if CONVENTIONAL.match(first):
            conventional += 1
        if "Signed-off-by:" in msg:
            signed_off += 1

total = len(messages)
fmt = None
if total:
    fmt = "conventional_commits" if conventional > total / 2 else "no_strong_pattern"

emit("commit-conventions", {
    "sample_size": total,
    "conventional": conventional,
    "signed_off": signed_off,
    "format": fmt,
    "signed_off_required": signed_off > 0,
    "examples": messages[:5],
}, warnings=warnings)
PYEOF
        ;;

    branch-conventions)
        REPO="$REPO" python3 <<'PYEOF'
import os
import re
from _envelope import emit, fail, fetch_json

REPO = os.environ["REPO"]
prs = fetch_json(f"/repos/{REPO}/pulls?state=closed&per_page=10")
if prs is None:
    fail("branch-conventions", f"could not fetch closed PRs for {REPO}")

merged = [p for p in prs if p.get("merged_at")]
if not merged:
    emit("branch-conventions", {
        "sample_size": 0, "patterns": {}, "numbered": 0,
        "dominant": None, "issue_numbers_in_branch": False, "examples": [],
    }, warnings=["no merged PRs found"])
    raise SystemExit(0)

branches = [p["head"]["ref"] for p in merged]
prefixes = ("feat/", "fix/", "docs/", "chore/", "refactor/", "test/")
patterns = {p: 0 for p in prefixes}
patterns["other"] = 0
numbered = 0

for b in branches:
    matched = False
    for prefix in prefixes:
        if b.startswith(prefix):
            patterns[prefix] += 1
            matched = True
            break
    if not matched:
        patterns["other"] += 1
    if re.search(r"/\d+-", b) or re.search(r"/#?\d+", b):
        numbered += 1

dominant = max(patterns, key=patterns.get)
if patterns[dominant] <= len(branches) / 2 or dominant == "other":
    dominant = None

emit("branch-conventions", {
    "sample_size": len(branches),
    "patterns": patterns,
    "numbered": numbered,
    "dominant": dominant,
    "issue_numbers_in_branch": numbered > len(branches) / 2,
    "examples": branches[:5],
})
PYEOF
        ;;

    ai-policy)
        REPO="$REPO" python3 <<'PYEOF'
import base64
import os
from _envelope import emit, fail, fetch_json

REPO = os.environ["REPO"]
repo_meta = fetch_json(f"/repos/{REPO}")
if not repo_meta or "default_branch" not in repo_meta:
    fail("ai-policy", f"could not fetch repo metadata for {REPO}")
ref = repo_meta["default_branch"]

results = []
for path in ("AI_POLICY.md", "CODE_OF_CONDUCT.md", "CONTRIBUTING.md"):
    d = fetch_json(f"/repos/{REPO}/contents/{path}?ref={ref}")
    if not d or "content" not in d:
        results.append({"path": path, "found": False, "content": None})
        continue
    try:
        content = base64.b64decode(d["content"]).decode("utf-8")
    except (ValueError, UnicodeDecodeError):
        results.append({"path": path, "found": False, "content": None})
        continue
    results.append({"path": path, "found": True, "content": content})

emit("ai-policy", {"default_branch": ref, "files": results})
PYEOF
        ;;

    disclosure-format)
        REPO="$REPO" python3 <<'PYEOF'
import base64
import os
import re
from _envelope import emit, fail, fetch_json

REPO = os.environ["REPO"]
repo_meta = fetch_json(f"/repos/{REPO}")
if not repo_meta or "default_branch" not in repo_meta:
    fail("disclosure-format", f"could not fetch repo metadata for {REPO}")
ref = repo_meta["default_branch"]

d = fetch_json(f"/repos/{REPO}/contents/AI_POLICY.md?ref={ref}")
if not d or "content" not in d:
    emit("disclosure-format", {"format": "none", "template": None},
         warnings=["AI_POLICY.md not found — no disclosure format required"])
    raise SystemExit(0)

try:
    content = base64.b64decode(d["content"]).decode("utf-8")
except (ValueError, UnicodeDecodeError):
    fail("disclosure-format", "could not decode AI_POLICY.md")

blocks = re.findall(r"```[\s\S]*?```", content)
template_block = None
for block in blocks:
    if "Tool:" in block or "Used for:" in block or "AI Assistance" in block:
        template_block = block.strip("`").strip()
        break

if template_block:
    emit("disclosure-format", {"format": "code_block", "template": template_block})
    raise SystemExit(0)

# Bullet/prose fallback — collect a small window around the disclosure heading
in_format = False
format_lines = []
for line in content.split("\n"):
    low = line.lower()
    if "format" in low or "disclos" in low or "include" in low:
        in_format = True
    if in_format:
        format_lines.append(line)
        if len(format_lines) > 10:
            break

if format_lines:
    emit("disclosure-format", {"format": "prose", "template": "\n".join(format_lines)})
    raise SystemExit(0)

emit("disclosure-format", {"format": "none", "template": None},
     warnings=["AI_POLICY.md exists but no specific disclosure template found — recommend voluntary disclosure"])
PYEOF
        ;;

    pr-stats)
        REPO="$REPO" python3 <<'PYEOF'
import os
from _envelope import emit, fail, fetch_json

REPO = os.environ["REPO"]
prs = fetch_json(f"/repos/{REPO}/pulls?state=closed&per_page=10")
if prs is None:
    fail("pr-stats", f"could not fetch closed PRs for {REPO}")

merged = [p for p in prs if p.get("merged_at")]
if not merged:
    emit("pr-stats", {"sample_size": 0}, warnings=["no merged PRs found"])
    raise SystemExit(0)

additions, deletions, files = [], [], []
for p in merged[:5]:
    detail = fetch_json(f"/repos/{REPO}/pulls/{p['number']}")
    if detail and "additions" in detail:
        additions.append(detail["additions"])
        deletions.append(detail["deletions"])
        files.append(detail["changed_files"])

if not additions:
    emit("pr-stats", {"sample_size": 0}, warnings=["could not fetch any PR details"])
    raise SystemExit(0)


def stats(values):
    s = sorted(values)
    n = len(s)
    median = s[n // 2] if n % 2 else (s[n // 2 - 1] + s[n // 2]) / 2
    return {"median": median, "min": min(s), "max": max(s)}


a, dst, f = stats(additions), stats(deletions), stats(files)
emit("pr-stats", {
    "sample_size": len(additions),
    "additions": a,
    "deletions": dst,
    "files": f,
    "guideline": {
        "max_additions": int(a["median"] * 2),
        "max_files": int(f["median"] * 2),
    },
})
PYEOF
        ;;

    conventions-config)
        REPO="$REPO" python3 <<'PYEOF'
import base64
import os
from _envelope import emit, fail, fetch_json

REPO = os.environ["REPO"]
repo_meta = fetch_json(f"/repos/{REPO}")
if not repo_meta or "default_branch" not in repo_meta:
    fail("conventions-config", f"could not fetch repo metadata for {REPO}")
ref = repo_meta["default_branch"]


def get_text(path):
    d = fetch_json(f"/repos/{REPO}/contents/{path}?ref={ref}")
    if not d or "content" not in d:
        return None
    try:
        return base64.b64decode(d["content"]).decode("utf-8")
    except (ValueError, UnicodeDecodeError):
        return None


ec = get_text(".editorconfig")
pc = get_text(".pre-commit-config.yaml")
pt = get_text("pyproject.toml")
pt_tool = None
if pt:
    in_tool = False
    keep = []
    for line in pt.split("\n"):
        if line.startswith("[tool."):
            in_tool = True
        elif line.startswith("[") and not line.startswith("[tool."):
            in_tool = False
        if in_tool:
            keep.append(line)
    pt_tool = "\n".join(keep) if keep else None

emit("conventions-config", {
    "default_branch": ref,
    "editorconfig": {"found": ec is not None, "content": ec},
    "pre_commit_config": {"found": pc is not None, "content": pc},
    "pyproject_tool": {"found": pt_tool is not None, "content": pt_tool},
})
PYEOF
        ;;

    contributing-requirements)
        REPO="$REPO" python3 <<'PYEOF'
import base64
import os
from _envelope import emit, fail, fetch_json

REPO = os.environ["REPO"]
repo_meta = fetch_json(f"/repos/{REPO}")
if not repo_meta or "default_branch" not in repo_meta:
    fail("contributing-requirements", f"could not fetch repo metadata for {REPO}")
ref = repo_meta["default_branch"]

d = fetch_json(f"/repos/{REPO}/contents/CONTRIBUTING.md?ref={ref}")
if not d or "content" not in d:
    emit("contributing-requirements", {"found": False, "content": None})
    raise SystemExit(0)

try:
    content = base64.b64decode(d["content"]).decode("utf-8")
except (ValueError, UnicodeDecodeError):
    fail("contributing-requirements", "could not decode CONTRIBUTING.md")

emit("contributing-requirements", {"found": True, "content": content})
PYEOF
        ;;

    codeowners)
        REPO="$REPO" python3 <<'PYEOF'
import base64
import os
from _envelope import emit, fail, fetch_json

REPO = os.environ["REPO"]
repo_meta = fetch_json(f"/repos/{REPO}")
if not repo_meta or "default_branch" not in repo_meta:
    fail("codeowners", f"could not fetch repo metadata for {REPO}")
ref = repo_meta["default_branch"]

content = None
for candidate in ("CODEOWNERS", ".github/CODEOWNERS", "docs/CODEOWNERS"):
    d = fetch_json(f"/repos/{REPO}/contents/{candidate}?ref={ref}")
    if not d or "content" not in d:
        continue
    try:
        content = base64.b64decode(d["content"]).decode("utf-8")
        break
    except (ValueError, UnicodeDecodeError):
        continue

if content is None:
    emit("codeowners", {"found": False, "rules": []})
    raise SystemExit(0)

rules = []
for line in content.strip().split("\n"):
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    parts = line.split()
    if parts:
        rules.append({"path": parts[0], "owners": parts[1:]})

emit("codeowners", {"found": True, "rules": rules})
PYEOF
        ;;

    legal)
        REPO="$REPO" python3 <<'PYEOF'
import os
from _envelope import emit, fail, fetch_json

REPO = os.environ["REPO"]
repo_meta = fetch_json(f"/repos/{REPO}")
if not repo_meta or "default_branch" not in repo_meta:
    fail("legal", f"could not fetch repo metadata for {REPO}")
ref = repo_meta["default_branch"]

ref_data = fetch_json(f"/repos/{REPO}/git/refs/heads/{ref}")
if not ref_data or "object" not in ref_data:
    fail("legal", f"could not resolve branch {ref}")
sha = ref_data["object"]["sha"]

warnings = []

# A 404 on the DCO endpoint legitimately means "no DCO file"; a
# network/auth failure also returns None. fetch_json can't distinguish
# the two, so dco_file is best-effort: False here means "we got nothing
# back at all", which encompasses both the absent-file and fetch-failed
# cases. There's no `dco_file_known` flag because there's no operation
# we could do to disambiguate without false certainty.
dco_resp = fetch_json(f"/repos/{REPO}/contents/DCO?ref={ref}")
dco_present = bool(dco_resp and "content" in dco_resp)

# Distinguish None (fetch failure) from empty results so consumers can
# trust an absent ci_workflows / signed_off_total reading.
tree = fetch_json(f"/repos/{REPO}/git/trees/{sha}?recursive=1")
if tree is None:
    workflows = []
    workflows_known = False
    warnings.append(
        f"could not fetch repository tree for {sha} — "
        "ci_workflows is incomplete"
    )
else:
    workflows = sorted(
        f["path"] for f in tree.get("tree", [])
        if f["path"].startswith(".github/workflows/")
    )
    workflows_known = True

commits = fetch_json(f"/repos/{REPO}/commits?per_page=5")
if commits is None:
    commits = []
    commits_known = False
    warnings.append(
        "could not fetch recent commits — "
        "signed_off_count / signed_off_total is incomplete"
    )
else:
    commits_known = True
signed = sum(
    1 for c in commits
    if "Signed-off-by:" in (c.get("commit", {}).get("message", "") or "")
)

license_data = fetch_json(f"/repos/{REPO}/license")
if license_data is None:
    license_info = None
    license_known = False
    warnings.append("could not fetch /license — `license` is incomplete")
else:
    lic = license_data.get("license") or {}
    license_info = (
        {"spdx_id": lic.get("spdx_id"), "name": lic.get("name")}
        if lic else None
    )
    license_known = True

emit("legal", {
    "default_branch": ref,
    "dco_file": dco_present,
    "ci_workflows": workflows,
    "ci_workflows_known": workflows_known,
    "signed_off_count": signed,
    "signed_off_total": len(commits),
    "signed_off_known": commits_known,
    "license": license_info,
    "license_known": license_known,
}, warnings=warnings)
PYEOF
        ;;

    templates-issue)
        REPO="$REPO" python3 <<'PYEOF'
import base64
import os
from _envelope import emit, fail, fetch_json

REPO = os.environ["REPO"]
repo_meta = fetch_json(f"/repos/{REPO}")
if not repo_meta or "default_branch" not in repo_meta:
    fail("templates-issue", f"could not fetch repo metadata for {REPO}")
ref = repo_meta["default_branch"]

ref_data = fetch_json(f"/repos/{REPO}/git/refs/heads/{ref}")
if not ref_data or "object" not in ref_data:
    fail("templates-issue", f"could not resolve branch {ref}")
sha = ref_data["object"]["sha"]

# Tree fetch failure must NOT silently look like "no templates" — that
# would let a transient API failure masquerade as a clean absent answer.
tree = fetch_json(f"/repos/{REPO}/git/trees/{sha}?recursive=1")
if tree is None:
    fail("templates-issue",
         f"could not fetch repository tree for {sha} — cannot enumerate templates")
paths = [
    item["path"] for item in tree.get("tree", [])
    if item.get("type") == "blob"
]

dir_templates = sorted(
    p for p in paths
    if p.startswith(".github/ISSUE_TEMPLATE/")
    and (p.endswith(".md") or p.endswith(".yml") or p.endswith(".yaml"))
)
legacy = [p for p in (".github/ISSUE_TEMPLATE.md", "ISSUE_TEMPLATE.md") if p in paths]
ordered = dir_templates if dir_templates else legacy

if not ordered:
    emit("templates-issue", {"default_branch": ref, "templates": []})
    raise SystemExit(0)

templates = []
fetch_failures = []
for path in ordered:
    d = fetch_json(f"/repos/{REPO}/contents/{path}?ref={ref}")
    if not d or "content" not in d:
        fetch_failures.append(path)
        continue
    try:
        body = base64.b64decode(d["content"]).decode("utf-8")
    except (ValueError, UnicodeDecodeError):
        fetch_failures.append(path)
        continue
    if not body.strip():
        continue  # treat empty file as absent — matches GitHub's own behavior
    templates.append({"path": path, "content": body.rstrip()})

# error-handling: don't let a fetch failure masquerade as "no templates".
# If discovery returned paths but every fetch failed, that's an upstream
# read failure, not absence — fail loudly so the consumer can't conclude
# "this repo has no issue templates".
if ordered and not templates and fetch_failures:
    fail("templates-issue",
         f"discovered {len(ordered)} template path(s) but could not fetch/decode any: "
         f"{', '.join(fetch_failures)}")

# Partial failure: some paths fetched, some didn't — keep the successes
# but warn about the missing ones so the consumer can spot incomplete
# data.
warnings = []
if fetch_failures and templates:
    warnings.append(
        f"could not fetch/decode {len(fetch_failures)} of {len(ordered)} "
        f"template path(s): {', '.join(fetch_failures)}"
    )

emit("templates-issue", {"default_branch": ref, "templates": templates}, warnings=warnings)
PYEOF
        ;;

    templates-pr)
        REPO="$REPO" python3 <<'PYEOF'
import base64
import os
from _envelope import emit, fail, fetch_json

REPO = os.environ["REPO"]
repo_meta = fetch_json(f"/repos/{REPO}")
if not repo_meta or "default_branch" not in repo_meta:
    fail("templates-pr", f"could not fetch repo metadata for {REPO}")
ref = repo_meta["default_branch"]

ref_data = fetch_json(f"/repos/{REPO}/git/refs/heads/{ref}")
if not ref_data or "object" not in ref_data:
    fail("templates-pr", f"could not resolve branch {ref}")
sha = ref_data["object"]["sha"]

tree = fetch_json(f"/repos/{REPO}/git/trees/{sha}?recursive=1")
if tree is None:
    fail("templates-pr",
         f"could not fetch repository tree for {sha} — cannot enumerate templates")
paths = [
    item["path"] for item in tree.get("tree", [])
    if item.get("type") == "blob"
]


def ci_match(path, candidate):
    return path.lower() == candidate.lower()


single_candidates = (
    ".github/PULL_REQUEST_TEMPLATE.md",
    "docs/PULL_REQUEST_TEMPLATE.md",
    "PULL_REQUEST_TEMPLATE.md",
)
single_found = []
for cand in single_candidates:
    for p in paths:
        if ci_match(p, cand):
            single_found.append(p)
            break

dir_templates = sorted(
    p for p in paths
    if p.lower().startswith(".github/pull_request_template/")
    and p.lower().endswith(".md")
)

# .github/PULL_REQUEST_TEMPLATE.md first, then directory templates,
# then docs/ and root fallbacks.
ordered = [p for p in single_found if p.lower().startswith(".github/pull_request_template.md")]
ordered.extend(dir_templates)
ordered.extend(p for p in single_found if not p.lower().startswith(".github/pull_request_template.md"))

if not ordered:
    emit("templates-pr", {"default_branch": ref, "templates": []})
    raise SystemExit(0)

templates = []
fetch_failures = []
for path in ordered:
    d = fetch_json(f"/repos/{REPO}/contents/{path}?ref={ref}")
    if not d or "content" not in d:
        fetch_failures.append(path)
        continue
    try:
        body = base64.b64decode(d["content"]).decode("utf-8")
    except (ValueError, UnicodeDecodeError):
        fetch_failures.append(path)
        continue
    if not body.strip():
        continue  # treat empty file as absent — matches GitHub's own behavior
    templates.append({"path": path, "content": body.rstrip()})

# Same semantics as templates-issue: discovered-but-unfetchable is an
# upstream read failure, not absence.
if ordered and not templates and fetch_failures:
    fail("templates-pr",
         f"discovered {len(ordered)} template path(s) but could not fetch/decode any: "
         f"{', '.join(fetch_failures)}")

warnings = []
if fetch_failures and templates:
    warnings.append(
        f"could not fetch/decode {len(fetch_failures)} of {len(ordered)} "
        f"template path(s): {', '.join(fetch_failures)}"
    )

emit("templates-pr", {"default_branch": ref, "templates": templates}, warnings=warnings)
PYEOF
        ;;

    *)
        CMD="$COMMAND" python3 <<'PYEOF'
import os
import sys
from _envelope import emit

cmd = os.environ.get("CMD", "")
available = [
    "repo-scan", "issue", "issue-comments", "check-claim",
    "issues-open", "issues-closed", "prs-closed", "pr-history",
    "related-prs", "pr-comments", "file", "commit-conventions",
    "branch-conventions", "ai-policy", "disclosure-format",
    "pr-stats", "conventions-config", "contributing-requirements",
    "codeowners", "legal", "templates-issue", "templates-pr",
]

# script-delegation.md self-error-handling: stderr diagnostic on every
# failure exit, even the dispatcher's unknown-command path.
if not cmd:
    sys.stderr.write("github.sh: no command provided. Run with one of: "
                     + ", ".join(available) + "\n")
    emit("help", {"available_commands": available},
         errors=["no command provided"], ok=False)
else:
    sys.stderr.write(f"github.sh: unknown command: {cmd}. Available: "
                     + ", ".join(available) + "\n")
    emit(cmd, {"available_commands": available},
         errors=[f"unknown command: {cmd}"], ok=False)
PYEOF
        exit 1
        ;;
esac
