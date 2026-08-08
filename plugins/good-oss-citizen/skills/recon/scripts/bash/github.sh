#!/usr/bin/env bash
# GitHub API helper for good-oss-citizen plugin.
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
from _templates import ISSUE_TEMPLATE_LEGACY_PATHS, issue_template_dir_paths

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
scan_warnings = []
if tree.get("truncated"):
    # A truncated listing silently omits entries, so `missing` below means
    # "not seen", not "not present".
    scan_warnings.append("tree listing truncated - treat `missing` as unconfirmed")

def categorize(targets):
    return {
        "found": [t for t in targets if t in paths],
        "missing": [t for t in targets if t not in paths],
    }

# GitHub resolves community health files from `.github/`, then the repository
# root, then `docs/`, taking the first hit. The tree is already in hand, so
# resolving all three locations here costs nothing and keeps this consistent
# with `ai-policy` / `contributing-requirements`; otherwise the same report
# would list CONTRIBUTING.md as missing while quoting its contents.
HEALTH_FILE_DIRS = (".github/", "", "docs/")


def resolve_health(name):
    for prefix in HEALTH_FILE_DIRS:
        candidate = f"{prefix}{name}"
        if candidate in paths:
            return candidate
    return None


def categorize_health(targets):
    found, missing = [], []
    for name in targets:
        resolved = resolve_health(name)
        (found.append(resolved) if resolved else missing.append(name))
    return {"found": found, "missing": missing}


# README resolves the same way: GitHub surfaces a readme from `.github/`, the
# root, or `docs/`. (The organisation profile readme is a different thing --
# it lives in the org's own `.github` *repository*, not in a `.github/`
# directory here.) LICENSE and DCO stay root-only: GitHub only detects a
# licence at the root.
root_only = categorize(["DCO", "LICENSE"])
policy_files = categorize_health([
    "CONTRIBUTING.md", "AI_POLICY.md", "CODE_OF_CONDUCT.md", "SECURITY.md",
    "README.md",
])
policy_files["found"] += root_only["found"]
policy_files["missing"] += root_only["missing"]
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
# CODEOWNERS resolves from `.github/`, the root, or `docs/` — the same order
# the `codeowners` command uses. Listing it as missing here while that command
# returns its rules is exactly the self-contradiction this change removes.
build_meta = categorize_health(["CODEOWNERS"])
_other_meta = categorize([
    "CHANGELOG.md", "DEVELOPMENT.md", "Makefile", "justfile", "Taskfile.yml",
])
build_meta["found"] += _other_meta["found"]
build_meta["missing"] += _other_meta["missing"]

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
issue_dir = issue_template_dir_paths(paths)
issue_legacy = [p for p in ISSUE_TEMPLATE_LEGACY_PATHS if p in paths]
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
}, warnings=scan_warnings)
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

    body)
        REPO="$REPO" ARG="$ARG" python3 <<'PYEOF'
import os
from _envelope import emit, fail, fetch_json

REPO = os.environ["REPO"]
ARG = os.environ["ARG"]
d = fetch_json(f"/repos/{REPO}/issues/{ARG}")
if not d or "number" not in d:
    fail("body", f"could not fetch issue or pull request {ARG} from {REPO}")

kind = "pull_request" if d.get("pull_request") else "issue"
emit("body", {
    "kind": kind,
    "number": d["number"],
    "title": d.get("title", ""),
    "state": d.get("state", ""),
    "url": d.get("html_url", ""),
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
from _envelope import (
    emit,
    fail,
    fetch_json,
    fetch_optional_json,
    health_candidates,
)

REPO = os.environ["REPO"]
repo_meta = fetch_json(f"/repos/{REPO}")
if not repo_meta or "default_branch" not in repo_meta:
    fail("ai-policy", f"could not fetch repo metadata for {REPO}")
ref = repo_meta["default_branch"]

# GitHub resolves community health files from `.github/`, then the repository
# root, then `docs/`, taking the first hit. Probing only the root meant a
# project whose CONTRIBUTING.md lives in `.github/` — one of the most common
# layouts — read as having no contribution guidance at all, and so no AI
# policy. Probe in GitHub's order and stop at the first readable match.
POLICY_DOCS = ("AI_POLICY.md", "CODE_OF_CONDUCT.md", "CONTRIBUTING.md")

warnings = []

def read_doc(name):
    """Resolve one health file in GitHub's precedence order.

    Stops at the first readable hit, so the common case where the file sits in
    `.github/` or at the root costs one or two lookups; only a document that is
    absent everywhere costs all three.
    """
    candidates = health_candidates(name)
    masked = False
    for path in candidates:
        d, found = fetch_optional_json(f"/repos/{REPO}/contents/{path}?ref={ref}")
        if found is False:
            continue
        if found is None:
            # A higher-precedence candidate we could not read must not be
            # silently masked by a lower-precedence hit: GitHub would serve
            # the one we failed to read, not the one we are about to return.
            masked = True
            continue
        if not d or "content" not in d:
            # 200 without content: a directory, or a symlink out of the repo.
            continue
        try:
            return path, base64.b64decode(d["content"]).decode("utf-8"), masked
        except (ValueError, UnicodeDecodeError):
            warnings.append(f"{path} is not valid UTF-8 - trying the next location")
            continue
    return None, None, masked


results = []
for name in POLICY_DOCS:
    path, content, masked = read_doc(name)
    if masked:
        if content is not None:
            warnings.append(
                f"a higher-precedence location for {name} could not be read - "
                "the file reported may not be the one GitHub serves"
            )
        else:
            # Nothing resolved, so the unreadable candidate need not have been
            # higher-precedence than anything; do not claim that it was.
            warnings.append(f"a location for {name} could not be read - its absence is unconfirmed")
    results.append({"path": path or name, "found": content is not None, "content": content})

emit("ai-policy", {"default_branch": ref, "files": results}, warnings=warnings)
PYEOF
        ;;

    disclosure-format)
        REPO="$REPO" python3 <<'PYEOF'
import base64
import os
import re
from _envelope import (
    emit,
    fail,
    fetch_json,
    fetch_optional_json,
    health_candidates,
)

REPO = os.environ["REPO"]
repo_meta = fetch_json(f"/repos/{REPO}")
if not repo_meta or "default_branch" not in repo_meta:
    fail("disclosure-format", f"could not fetch repo metadata for {REPO}")
ref = repo_meta["default_branch"]

# Resolve in GitHub's precedence order, using the tree to avoid probing
# locations that cannot exist.
warnings = []
candidates = health_candidates("AI_POLICY.md")

content = None
masked = False
for path in candidates:
    d, found = fetch_optional_json(f"/repos/{REPO}/contents/{path}?ref={ref}")
    if found is False:
        continue
    if found is None:
        masked = True
        continue
    # 200 without content: a directory, or a symlink out of the repo.
    if not d or "content" not in d:
        continue
    try:
        content = base64.b64decode(d["content"]).decode("utf-8")
    except (ValueError, UnicodeDecodeError):
        # Match ai-policy: try the next location rather than failing outright.
        warnings.append(f"{path} is not valid UTF-8 - trying the next location")
        continue
    break

if masked:
    if content is not None:
        warnings.append(
            "a higher-precedence AI policy location could not be read - "
            "the policy reported may not be the one GitHub serves"
        )
    else:
        warnings.append("an AI policy location could not be read - its absence is unconfirmed")

if content is None:
    emit("disclosure-format", {"format": "none", "template": None},
         warnings=warnings + ["AI_POLICY.md not found — no disclosure format required"])
    raise SystemExit(0)

blocks = re.findall(r"```[\s\S]*?```", content)
template_block = None
for block in blocks:
    if "Tool:" in block or "Used for:" in block or "AI Assistance" in block:
        template_block = block.strip("`").strip()
        break

if template_block:
    emit("disclosure-format", {"format": "code_block", "template": template_block},
         warnings=warnings)
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
     warnings=warnings + ["AI_POLICY.md exists but no specific disclosure template found — recommend voluntary disclosure"])
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
from _envelope import (
    emit,
    fail,
    fetch_json,
    fetch_optional_json,
    health_candidates,
)

REPO = os.environ["REPO"]
repo_meta = fetch_json(f"/repos/{REPO}")
if not repo_meta or "default_branch" not in repo_meta:
    fail("contributing-requirements", f"could not fetch repo metadata for {REPO}")
ref = repo_meta["default_branch"]

# Resolve in GitHub's precedence order, using the tree to avoid probing
# locations that cannot exist.
warnings = []
candidates = health_candidates("CONTRIBUTING.md")

masked = False
for path in candidates:
    d, found = fetch_optional_json(f"/repos/{REPO}/contents/{path}?ref={ref}")
    if found is False:
        continue
    if found is None:
        masked = True
        continue
    # 200 without content: a directory, or a symlink out of the repo.
    if not d or "content" not in d:
        continue
    try:
        content = base64.b64decode(d["content"]).decode("utf-8")
    except (ValueError, UnicodeDecodeError):
        # Match ai-policy: try the next location rather than failing outright.
        warnings.append(f"{path} is not valid UTF-8 - trying the next location")
        continue
    if masked:
        warnings.append(
            "a higher-precedence CONTRIBUTING.md location could not be read - "
            "the file reported may not be the one GitHub serves"
        )
    emit("contributing-requirements", {"found": True, "content": content, "path": path},
         warnings=warnings)
    raise SystemExit(0)

if masked:
    warnings.append(
        "a CONTRIBUTING.md location could not be read - its absence is unconfirmed"
    )
emit("contributing-requirements", {"found": False, "content": None, "path": None},
     warnings=warnings)
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
# GitHub resolves CODEOWNERS from `.github/`, then the root, then `docs/`.
for candidate in (".github/CODEOWNERS", "CODEOWNERS", "docs/CODEOWNERS"):
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
from _envelope import emit, fail, fetch_json, fetch_optional_json

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

# Degrade rather than abort, matching how this command already treats its
# tree, commits and licence reads: one unresolved optional file must not throw
# away the licence and sign-off findings alongside it. `dco_file_known` lets a
# caller tell "no DCO" from "could not tell".
dco_resp, dco_found = fetch_optional_json(f"/repos/{REPO}/contents/DCO?ref={ref}")
dco_known = dco_found is not None
if not dco_known:
    warnings.append("could not determine whether a DCO file exists - treat dco_file as unknown")
dco_present = bool(dco_found and dco_resp and "content" in dco_resp)

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
    "dco_file_known": dco_known,
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
from _templates import ISSUE_TEMPLATE_LEGACY_PATHS, issue_template_dir_paths

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

dir_templates = issue_template_dir_paths(paths, extensions=(".md", ".yml", ".yaml"))
legacy = [p for p in ISSUE_TEMPLATE_LEGACY_PATHS if p in paths]
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
    "repo-scan", "issue", "body", "issue-comments", "check-claim",
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
