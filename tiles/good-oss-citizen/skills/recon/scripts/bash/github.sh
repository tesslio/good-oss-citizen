#!/usr/bin/env bash
# GitHub API helper for good-oss-citizen tile
# Tries gh CLI first, falls back to curl for public repos
#
# Usage:
#   github.sh repo-scan <owner/repo>               - Scan repo for policy/convention files
#   github.sh issue <owner/repo> <number>           - Get issue details
#   github.sh issue-comments <owner/repo> <number>  - Get issue comments
#   github.sh check-claim <owner/repo> <number>     - Check if issue is claimed
#   github.sh issues-open <owner/repo>              - List open issues
#   github.sh issues-closed <owner/repo>            - List closed issues
#   github.sh prs-closed <owner/repo>               - List closed PRs
#   github.sh pr-history <owner/repo>               - Closed PRs with rejection reasons
#   github.sh pr-comments <owner/repo> <number>     - Get PR comments
#   github.sh file <owner/repo> <path>              - Get file contents
#   github.sh templates-issue <owner/repo>          - Fetch all issue templates with contents
#   github.sh templates-pr <owner/repo>             - Fetch all PR templates with contents

set -euo pipefail

COMMAND="${1:-}"
REPO="${2:-}"
ARG="${3:-}"

API="https://api.github.com"

fetch() {
    local endpoint="$1"
    if command -v gh &>/dev/null; then
        gh api "$endpoint" 2>/dev/null && return 0
    fi
    curl -sf -H "Accept: application/vnd.github+json" "${API}${endpoint}" 2>/dev/null
}

case "$COMMAND" in
    repo-scan)
        # Get default branch first, then its tree
        DEFAULT_BRANCH=$(fetch "/repos/${REPO}" | python3 -c "import sys,json; print(json.load(sys.stdin)['default_branch'])")
        BRANCH_SHA=$(fetch "/repos/${REPO}/git/refs/heads/${DEFAULT_BRANCH}" | python3 -c "import sys,json; print(json.load(sys.stdin)['object']['sha'])")
        fetch "/repos/${REPO}/git/trees/${BRANCH_SHA}?recursive=1" | python3 -c "
import sys, json

tree = json.load(sys.stdin).get('tree', [])
paths = {item['path'] for item in tree if item.get('type') == 'blob'}

def check(files, label):
    found = [f for f in files if f in paths]
    missing = [f for f in files if f not in paths]
    print(f'\n=== {label} ===')
    if found: print(f'FOUND: {\", \".join(found)}')
    if missing: print(f'NOT FOUND: {\", \".join(missing)}')

check([
    'CONTRIBUTING.md', 'AI_POLICY.md', 'CODE_OF_CONDUCT.md',
    'SECURITY.md', 'DCO', 'LICENSE', 'README.md'
], 'Policy Files')

check([
    'AGENTS.md', 'CLAUDE.md', '.cursorrules',
    '.github/copilot-instructions.md', 'HOWTOAI.md', 'PROMPTING.md'
], 'Agent Instruction Files')

check([
    '.editorconfig', '.prettierrc', 'rustfmt.toml', '.clang-format',
    'pyproject.toml', '.pre-commit-config.yaml',
    'commitlint.config.js', 'commitlint.config.cjs',
    '.golangci.yml', 'Cargo.toml', 'go.mod'
], 'Convention Files')

# Templates — presence only; use templates-pr / templates-issue for contents
pr_template_paths = [
    '.github/PULL_REQUEST_TEMPLATE.md', '.github/pull_request_template.md',
    'docs/PULL_REQUEST_TEMPLATE.md', 'PULL_REQUEST_TEMPLATE.md',
]
pr_dir_templates = [p for p in paths if p.startswith('.github/PULL_REQUEST_TEMPLATE/')]
pr_found = [p for p in pr_template_paths if p in paths] + pr_dir_templates
print(f'\n=== PR Templates ===')
if pr_found:
    print(f'FOUND: {\", \".join(pr_found)} (run templates-pr for contents)')
else:
    print('NOT FOUND')

issue_templates = [p for p in paths if p.startswith('.github/ISSUE_TEMPLATE')]
legacy_issue = [p for p in ['.github/ISSUE_TEMPLATE.md', 'ISSUE_TEMPLATE.md'] if p in paths]
issue_found = issue_templates + legacy_issue
print(f'\n=== Issue Templates ===')
if issue_found:
    print(f'FOUND: {\", \".join(issue_found)} (run templates-issue for contents)')
else:
    print('NOT FOUND')

# Check for test fixtures
fixtures = [p for p in paths if 'conftest.py' in p or 'test_helper' in p or 'testutil' in p]
if fixtures:
    print(f'\n=== Test Fixtures ===')
    print(f'FOUND: {\", \".join(fixtures)}')

check([
    'CHANGELOG.md', 'CODEOWNERS', 'DEVELOPMENT.md', 'Makefile',
    'justfile', 'Taskfile.yml'
], 'Build/Meta Files')

# CI workflows
workflows = [p for p in paths if p.startswith('.github/workflows/')]
if workflows:
    print(f'\n=== CI Workflows ===')
    print(f'FOUND: {\", \".join(workflows)}')
"
        ;;
    issue)
        fetch "/repos/${REPO}/issues/${ARG}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f\"#{d['number']}: {d['title']}\")
print(f\"State: {d['state']}\")
print(f\"Labels: {', '.join(l['name'] for l in d.get('labels', []))}\")
if d.get('assignee'): print(f\"Assigned to: {d['assignee']['login']}\")
print(f\"\n{d['body']}\")
"
        ;;
    issue-comments)
        fetch "/repos/${REPO}/issues/${ARG}/comments" | python3 -c "
import sys, json
comments = json.load(sys.stdin)
if not comments:
    print('No comments.')
else:
    for c in comments:
        print(f\"--- {c['user']['login']} ({c['created_at'][:10]}) ---\")
        print(c['body'])
        print()
"
        ;;
    check-claim)
        # DEPRECATED: Use issue-comments instead and let the LLM judge whether someone claimed the issue.
        # Regex matching can't handle claims in other languages or non-standard phrasing.
        echo "DEPRECATED: Use 'issue-comments' instead. The LLM should interpret whether any comment indicates a claim."
        echo "Running issue-comments as fallback:"
        fetch "/repos/${REPO}/issues/${ARG}/comments" | python3 -c "
import sys, json
comments = json.load(sys.stdin)
if not comments:
    print('No comments.')
else:
    for c in comments:
        print(f\"--- {c['user']['login']} ({c['created_at'][:10]}) ---\")
        print(c['body'])
        print()
"
        ;;
    issues-open)
        fetch "/repos/${REPO}/issues?state=open&per_page=30" | python3 -c "
import sys, json
issues = [i for i in json.load(sys.stdin) if 'pull_request' not in i]
for i in issues:
    labels = ', '.join(l['name'] for l in i.get('labels', []))
    assignee = i['assignee']['login'] if i.get('assignee') else 'unassigned'
    print(f\"#{i['number']}: {i['title']} [{labels}] ({assignee})\")
"
        ;;
    issues-closed)
        fetch "/repos/${REPO}/issues?state=closed&per_page=30" | python3 -c "
import sys, json
issues = [i for i in json.load(sys.stdin) if 'pull_request' not in i]
for i in issues:
    labels = ', '.join(l['name'] for l in i.get('labels', []))
    reason = i.get('state_reason', 'completed')
    print(f\"#{i['number']}: {i['title']} [{labels}] (closed: {reason})\")
"
        ;;
    prs-closed)
        fetch "/repos/${REPO}/pulls?state=closed&per_page=30" | python3 -c "
import sys, json
for p in json.load(sys.stdin):
    merged = 'merged' if p.get('merged_at') else 'closed'
    print(f\"PR #{p['number']}: {p['title']} ({merged})\")
"
        ;;
    pr-history)
        # Get closed PRs with their rejection comments — one-stop shop
        export REPO API
        fetch "/repos/${REPO}/pulls?state=closed&per_page=20" | python3 -c "
import sys, json, subprocess, os

API = os.environ.get('API', 'https://api.github.com')
REPO = os.environ.get('REPO', '')
prs = json.load(sys.stdin)

for p in prs:
    merged = 'MERGED' if p.get('merged_at') else 'CLOSED'
    print(f\"{'='*60}\")
    print(f\"PR #{p['number']}: {p['title']} ({merged})\")
    if merged == 'MERGED':
        print('  (merged successfully)')
    else:
        # Fetch comments for rejected PRs
        try:
            cmd = ['curl', '-sf', '-H', 'Accept: application/vnd.github+json',
                   f'{API}/repos/{REPO}/issues/{p[\"number\"]}/comments']
            result = subprocess.run(cmd, capture_output=True, text=True)
            comments = json.loads(result.stdout or '[]')
            if comments:
                print('  Rejection feedback:')
                for c in comments:
                    # Truncate long comments
                    body = c['body'][:500]
                    print(f\"    {c['user']['login']}: {body}\")
            else:
                print('  (no comments)')
        except:
            print('  (could not fetch comments)')
    print()
"
        ;;
    related-prs)
        # Find closed PRs related to a specific issue number
        export REPO API
        ISSUE_NUM="${ARG}"
        TMPFILE=$(mktemp)
        fetch "/repos/${REPO}/pulls?state=closed&per_page=20" > "$TMPFILE"
        TMPFILE="$TMPFILE" REPO="$REPO" API="$API" ISSUE_NUM="$ISSUE_NUM" python3 -c "
import json, subprocess, os, re

API = os.environ['API']
REPO = os.environ['REPO']
ISSUE_NUM = os.environ['ISSUE_NUM']

with open(os.environ['TMPFILE']) as f:
    prs = json.load(f)
os.unlink(os.environ['TMPFILE'])

found = []
for p in prs:
    title = p.get('title', '')
    body = p.get('body', '') or ''
    # Check if PR references this issue
    if f'#{ISSUE_NUM}' in body or f'#{ISSUE_NUM}' in title or f'issue {ISSUE_NUM}' in body.lower():
        found.append(p)

if not found:
    print(f'No closed PRs found referencing issue #{ISSUE_NUM}.')
    exit(0)

print(f'=== Closed PRs related to issue #{ISSUE_NUM} ===')
for p in found:
    num = p['number']
    merged = 'MERGED' if p.get('merged_at') else 'CLOSED'
    print(f'')
    print(f'PR #{num}: {p[\"title\"]} ({merged})')
    if merged == 'CLOSED':
        try:
            cmd = ['curl', '-sf', '-H', 'Accept: application/vnd.github+json',
                   f'{API}/repos/{REPO}/issues/{num}/comments']
            result = subprocess.run(cmd, capture_output=True, text=True)
            comments = json.loads(result.stdout or '[]')
            if comments:
                print(f'  Rejection feedback:')
                for c in comments:
                    body = c['body'][:500]
                    print(f'    {c[\"user\"][\"login\"]}: {body}')
        except:
            pass
"
        ;;
    pr-comments)
        fetch "/repos/${REPO}/issues/${ARG}/comments" | python3 -c "
import sys, json
comments = json.load(sys.stdin)
if not comments:
    print('No comments.')
else:
    for c in comments:
        print(f\"--- {c['user']['login']} ({c['created_at'][:10]}) ---\")
        print(c['body'])
        print()
"
        ;;
    file)
        fetch "/repos/${REPO}/contents/${ARG}" | python3 -c "
import sys, json, base64
d = json.load(sys.stdin)
print(base64.b64decode(d['content']).decode('utf-8'))
"
        ;;
    commit-conventions)
        # Analyze commit messages from merged PRs
        TMPFILE=$(mktemp)
        fetch "/repos/${REPO}/pulls?state=closed&per_page=10" > "$TMPFILE"
        TMPFILE="$TMPFILE" REPO="$REPO" API="$API" python3 -c "
import json, re, subprocess, os

API = os.environ['API']
REPO = os.environ['REPO']

with open(os.environ['TMPFILE']) as f:
    prs = json.load(f)
os.unlink(os.environ['TMPFILE'])

merged = [p for p in prs if p.get('merged_at')]
if not merged:
    print('No merged PRs found.')
    exit(0)

conventional = 0
signed_off = 0
messages = []

for p in merged[:5]:
    try:
        num = p['number']
        cmd = ['curl', '-sf', '-H', 'Accept: application/vnd.github+json',
               f'{API}/repos/{REPO}/pulls/{num}/commits']
        result = subprocess.run(cmd, capture_output=True, text=True)
        commits = json.loads(result.stdout or '[]')
        for commit in commits:
            msg = commit.get('commit', {}).get('message', '')
            if msg:
                first_line = msg.split(chr(10))[0]
                if first_line.startswith('Merge '):
                    continue
                messages.append(first_line)
                if re.match(r'^(feat|fix|docs|chore|refactor|test|style|perf|ci|build|revert)(\(.+\))?:', first_line):
                    conventional += 1
                if 'Signed-off-by:' in msg:
                    signed_off += 1
    except:
        pass

total = len(messages)
if total == 0:
    print('No commit messages found.')
    exit(0)

print('=== Commit Convention Analysis ===')
if conventional > total / 2:
    print(f'Format: Conventional Commits ({conventional}/{total} commits)')
else:
    print(f'Format: No strong Conventional Commits pattern ({conventional}/{total})')
if signed_off > 0:
    print(f'Signed-off-by: REQUIRED ({signed_off}/{total} commits have it)')
else:
    print(f'Signed-off-by: not detected')
print(f'')
print(f'Examples from merged PRs:')
for m in messages[:5]:
    print(f'  {m}')
"
        ;;
    branch-conventions)
        # Analyze branch names from merged PRs
        fetch "/repos/${REPO}/pulls?state=closed&per_page=10" | python3 -c '
import sys, json, re

prs = json.load(sys.stdin)
merged = [p for p in prs if p.get("merged_at")]

if not merged:
    print("No merged PRs found.")
    sys.exit(0)

branches = [p["head"]["ref"] for p in merged]
patterns = {"feat/": 0, "fix/": 0, "docs/": 0, "chore/": 0, "other": 0}
numbered = 0

print("=== Branch Naming Analysis ===")
for b in branches:
    matched = False
    for prefix in ["feat/", "fix/", "docs/", "chore/", "refactor/", "test/"]:
        if b.startswith(prefix):
            patterns[prefix] = patterns.get(prefix, 0) + 1
            matched = True
            break
    if not matched:
        patterns["other"] += 1
    if re.search(r"/\d+-", b) or re.search(r"/#?\d+", b):
        numbered += 1

dominant = max(patterns, key=patterns.get)
if patterns[dominant] > len(branches) / 2 and dominant != "other":
    print(f"Pattern: <type>/<description> (e.g., {dominant}<description>)")
    if numbered > len(branches) / 2:
        print(f"Issue numbers: YES — include issue number (e.g., fix/123-description)")
else:
    print("Pattern: No strong convention detected")

print(f"\nExamples from merged PRs:")
for b in branches[:5]:
    print(f"  {b}")
'
        ;;
    ai-policy)
        # Fetch all policy-relevant files and return their contents for LLM interpretation.
        # The LLM determines the AI stance (banned, disclosure required, conditional, no policy)
        # because policies are written in free-form prose that regex can't reliably parse.
        DEFAULT_BRANCH=$(fetch "/repos/${REPO}" | python3 -c "import sys,json; print(json.load(sys.stdin)['default_branch'])")

        echo "=== AI Policy Files ==="

        for PFILE in AI_POLICY.md CODE_OF_CONDUCT.md CONTRIBUTING.md; do
            CONTENT=$(fetch "/repos/${REPO}/contents/${PFILE}?ref=${DEFAULT_BRANCH}" 2>/dev/null | python3 -c "
import sys, json, base64
try:
    d = json.load(sys.stdin)
    print(base64.b64decode(d['content']).decode('utf-8'))
except:
    pass
" 2>/dev/null || echo "")

            if [ -n "$CONTENT" ]; then
                echo ""
                echo "--- ${PFILE} ---"
                echo "$CONTENT"
            else
                echo ""
                echo "--- ${PFILE}: NOT FOUND ---"
            fi
        done

        echo ""
        echo "=== Determine AI stance from the above files ==="
        echo "Read the files above and determine: is AI banned, is disclosure required,"
        echo "are there conditions or restrictions (e.g., good-first-issue labels),"
        echo "or is there no AI policy at all? Policies may be in any language or phrasing."
        ;;
    disclosure-format)
        # Extract the disclosure template from AI_POLICY.md
        DEFAULT_BRANCH=$(fetch "/repos/${REPO}" | python3 -c "import sys,json; print(json.load(sys.stdin)['default_branch'])")
        fetch "/repos/${REPO}/contents/AI_POLICY.md?ref=${DEFAULT_BRANCH}" 2>/dev/null | python3 -c '
import sys, json, base64, re

try:
    d = json.load(sys.stdin)
    content = base64.b64decode(d["content"]).decode("utf-8")
except:
    print("No AI_POLICY.md found — no disclosure format required.")
    sys.exit(0)

# Look for code blocks that look like templates
blocks = re.findall(r"```[\s\S]*?```", content)
template_block = None
for block in blocks:
    if "Tool:" in block or "Used for:" in block or "AI Assistance" in block:
        template_block = block.strip("`").strip()
        break

if template_block:
    print("=== Disclosure Format (copy-paste ready) ===")
    print(template_block)
else:
    # Look for bullet-style format
    lines = content.split("\n")
    in_format = False
    format_lines = []
    for line in lines:
        if "format" in line.lower() or "disclos" in line.lower() or "include" in line.lower():
            in_format = True
        if in_format:
            format_lines.append(line)
            if len(format_lines) > 10:
                break
    if format_lines:
        print("=== Disclosure Format ===")
        print("\n".join(format_lines))
    else:
        print("AI_POLICY.md exists but no specific disclosure template found.")
        print("Recommend voluntary disclosure: Tool, what it was used for, what was human-written.")
' 2>/dev/null || echo "Could not extract disclosure format"
        ;;
    pr-stats)
        # Compute PR size statistics from merged PRs
        TMPFILE=$(mktemp)
        fetch "/repos/${REPO}/pulls?state=closed&per_page=10" > "$TMPFILE"
        TMPFILE="$TMPFILE" REPO="$REPO" API="$API" python3 -c "
import json, subprocess, os

API = os.environ['API']
REPO = os.environ['REPO']

with open(os.environ['TMPFILE']) as f:
    prs = json.load(f)
os.unlink(os.environ['TMPFILE'])

merged = [p for p in prs if p.get('merged_at')]
if not merged:
    print('No merged PRs found.')
    exit(0)

additions = []
deletions = []
files = []

for p in merged[:5]:
    try:
        num = p['number']
        cmd = ['curl', '-sf', '-H', 'Accept: application/vnd.github+json',
               f'{API}/repos/{REPO}/pulls/{num}']
        result = subprocess.run(cmd, capture_output=True, text=True)
        detail = json.loads(result.stdout or '{}')
        if 'additions' in detail:
            additions.append(detail['additions'])
            deletions.append(detail['deletions'])
            files.append(detail['changed_files'])
    except:
        pass

if not additions:
    print('Could not fetch PR details.')
    exit(0)

additions.sort()
deletions.sort()
files.sort()

def median(lst):
    n = len(lst)
    if n == 0: return 0
    if n % 2 == 0: return (lst[n//2-1] + lst[n//2]) / 2
    return lst[n//2]

print('=== PR Size Statistics (from merged PRs) ===')
print(f'Sample size: {len(additions)} merged PRs')
print(f'Additions: median={int(median(additions))}, min={min(additions)}, max={max(additions)}')
print(f'Deletions: median={int(median(deletions))}, min={min(deletions)}, max={max(deletions)}')
print(f'Files changed: median={int(median(files))}, min={min(files)}, max={max(files)}')
print(f'')
print(f'Guideline: Keep your PR within ~{int(median(additions)*2)} additions and ~{int(median(files)*2)} files.')
"
        ;;
    conventions-config)
        # Read .editorconfig and .pre-commit-config.yaml, extract key settings
        DEFAULT_BRANCH=$(fetch "/repos/${REPO}" | python3 -c "import sys,json; print(json.load(sys.stdin)['default_branch'])")

        echo "=== Code Convention Config ==="

        # .editorconfig
        EC=$(fetch "/repos/${REPO}/contents/.editorconfig?ref=${DEFAULT_BRANCH}" 2>/dev/null | python3 -c "
import sys, json, base64
try:
    d = json.load(sys.stdin)
    print(base64.b64decode(d['content']).decode('utf-8'))
except:
    print('')
" 2>/dev/null || echo "")

        if [ -n "$EC" ]; then
            echo ""
            echo ".editorconfig FOUND:"
            echo "$EC"
        else
            echo ""
            echo ".editorconfig: NOT FOUND"
        fi

        # .pre-commit-config.yaml
        PC=$(fetch "/repos/${REPO}/contents/.pre-commit-config.yaml?ref=${DEFAULT_BRANCH}" 2>/dev/null | python3 -c "
import sys, json, base64
try:
    d = json.load(sys.stdin)
    print(base64.b64decode(d['content']).decode('utf-8'))
except:
    print('')
" 2>/dev/null || echo "")

        if [ -n "$PC" ]; then
            echo ""
            echo ".pre-commit-config.yaml FOUND:"
            echo "$PC"
        else
            echo ""
            echo ".pre-commit-config.yaml: NOT FOUND"
        fi

        # pyproject.toml tool sections
        PT=$(fetch "/repos/${REPO}/contents/pyproject.toml?ref=${DEFAULT_BRANCH}" 2>/dev/null | python3 -c "
import sys, json, base64
try:
    d = json.load(sys.stdin)
    content = base64.b64decode(d['content']).decode('utf-8')
    # Extract [tool.*] sections
    in_tool = False
    for line in content.split('\n'):
        if line.startswith('[tool.'):
            in_tool = True
        elif line.startswith('[') and not line.startswith('[tool.'):
            in_tool = False
        if in_tool:
            print(line)
except:
    pass
" 2>/dev/null || echo "")

        if [ -n "$PT" ]; then
            echo ""
            echo "pyproject.toml tool config:"
            echo "$PT"
        fi
        ;;
    contributing-requirements)
        # Fetch CONTRIBUTING.md and return its full contents for LLM interpretation.
        # The LLM determines requirements (DCO, changelog, tests, issue-first, etc.)
        # because contribution guidelines are free-form prose with project-specific nuance.
        DEFAULT_BRANCH=$(fetch "/repos/${REPO}" | python3 -c "import sys,json; print(json.load(sys.stdin)['default_branch'])")
        CONTENT=$(fetch "/repos/${REPO}/contents/CONTRIBUTING.md?ref=${DEFAULT_BRANCH}" 2>/dev/null | python3 -c '
import sys, json, base64
try:
    d = json.load(sys.stdin)
    print(base64.b64decode(d["content"]).decode("utf-8"))
except:
    pass
' 2>/dev/null || echo "")

        if [ -n "$CONTENT" ]; then
            echo "=== CONTRIBUTING.md ==="
            echo "$CONTENT"
            echo ""
            echo "=== Determine requirements from the above ==="
            echo "Read CONTRIBUTING.md and determine: is DCO/sign-off required or recommended?"
            echo "Are tests required? Is there an issue-first policy? Changelog updates?"
            echo "Commit format? Branch naming? Any other contribution requirements?"
        else
            echo "CONTRIBUTING.md: NOT FOUND"
        fi
        ;;
    codeowners)
        # Parse CODEOWNERS file
        DEFAULT_BRANCH=$(fetch "/repos/${REPO}" | python3 -c "import sys,json; print(json.load(sys.stdin)['default_branch'])")
        fetch "/repos/${REPO}/contents/CODEOWNERS?ref=${DEFAULT_BRANCH}" 2>/dev/null | python3 -c '
import sys, json, base64

try:
    d = json.load(sys.stdin)
    content = base64.b64decode(d["content"]).decode("utf-8")
except:
    print("CODEOWNERS: NOT FOUND")
    sys.exit(0)

print("=== Code Owners ===")
for line in content.strip().split("\n"):
    line = line.strip()
    if line and not line.startswith("#"):
        parts = line.split()
        path = parts[0]
        owners = " ".join(parts[1:])
        print(f"  {path} → {owners}")
' 2>/dev/null || echo "CODEOWNERS: NOT FOUND"
        ;;
    legal)
        # Check for DCO, CLA, license
        DEFAULT_BRANCH=$(fetch "/repos/${REPO}" | python3 -c "import sys,json; print(json.load(sys.stdin)['default_branch'])")
        BRANCH_SHA=$(fetch "/repos/${REPO}/git/refs/heads/${DEFAULT_BRANCH}" | python3 -c "import sys,json; print(json.load(sys.stdin)['object']['sha'])")

        echo "=== Legal Requirements ==="

        # Check for DCO file
        DCO=$(fetch "/repos/${REPO}/contents/DCO?ref=${DEFAULT_BRANCH}" 2>/dev/null | python3 -c "
import sys, json
try:
    json.load(sys.stdin)
    print('FOUND')
except:
    print('NOT FOUND')
" 2>/dev/null || echo "NOT FOUND")
        echo "DCO file: $DCO"

        # Check for CLA in CI
        fetch "/repos/${REPO}/git/trees/${BRANCH_SHA}?recursive=1" 2>/dev/null | python3 -c "
import sys, json
tree = json.load(sys.stdin).get('tree', [])
workflows = [f['path'] for f in tree if f['path'].startswith('.github/workflows/')]
print('CI workflows: ' + ', '.join(workflows) if workflows else 'CI workflows: none')
" 2>/dev/null

        # Check for Signed-off-by in recent commits
        fetch "/repos/${REPO}/commits?per_page=5" 2>/dev/null | python3 -c "
import sys, json
commits = json.load(sys.stdin)
signed = sum(1 for c in commits if 'Signed-off-by:' in c.get('commit', {}).get('message', ''))
total = len(commits)
if signed > 0:
    print(f'Signed-off-by in commits: YES ({signed}/{total} recent commits)')
else:
    print('Signed-off-by in commits: not detected')
" 2>/dev/null

        # License
        fetch "/repos/${REPO}/license" 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    lic = d.get('license', {})
    print(f\"License: {lic.get('spdx_id', 'unknown')} ({lic.get('name', 'unknown')})\")
except:
    print('License: not detected')
" 2>/dev/null
        ;;
    templates-issue)
        # Enumerate issue templates on the default branch, priority order:
        #   1. .github/ISSUE_TEMPLATE/ directory (all *.md and *.yml)
        #   2. .github/ISSUE_TEMPLATE.md (legacy single template)
        #   3. ISSUE_TEMPLATE.md at repo root (legacy)
        # Empty files are treated as absent.
        DEFAULT_BRANCH=$(fetch "/repos/${REPO}" | python3 -c "import sys,json; print(json.load(sys.stdin)['default_branch'])")
        BRANCH_SHA=$(fetch "/repos/${REPO}/git/refs/heads/${DEFAULT_BRANCH}" | python3 -c "import sys,json; print(json.load(sys.stdin)['object']['sha'])")

        export REPO API DEFAULT_BRANCH
        fetch "/repos/${REPO}/git/trees/${BRANCH_SHA}?recursive=1" | python3 -c "
import sys, json, os, subprocess, base64

API = os.environ['API']
REPO = os.environ['REPO']
REF = os.environ['DEFAULT_BRANCH']

tree = json.load(sys.stdin).get('tree', [])
paths = [item['path'] for item in tree if item.get('type') == 'blob']

dir_templates = sorted([
    p for p in paths
    if p.startswith('.github/ISSUE_TEMPLATE/')
    and (p.endswith('.md') or p.endswith('.yml') or p.endswith('.yaml'))
])
legacy = [p for p in ['.github/ISSUE_TEMPLATE.md', 'ISSUE_TEMPLATE.md'] if p in paths]
# Honor priority: directory first, then legacy — but only include legacy if no directory templates
ordered = dir_templates if dir_templates else legacy

if not ordered:
    print('No issue templates found.')
    sys.exit(0)

def get_file(path):
    cmd = ['curl', '-sf', '-H', 'Accept: application/vnd.github+json',
           f'{API}/repos/{REPO}/contents/{path}?ref={REF}']
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
    except OSError as e:
        sys.stderr.write(f'github.sh: failed to invoke curl for {path}: {e}\n')
        sys.exit(1)
    if result.returncode != 0:
        sys.stderr.write(
            f'github.sh: curl failed for {path} (rc={result.returncode}); '
            f'stderr: {result.stderr.strip()}\n'
        )
        sys.exit(1)
    body = result.stdout or ''
    if not body.strip():
        sys.stderr.write(f'github.sh: empty response for {path}\n')
        sys.exit(1)
    try:
        d = json.loads(body)
    except json.JSONDecodeError as e:
        sys.stderr.write(
            f'github.sh: non-JSON response for {path}: {e}; '
            f'first 120 bytes: {body[:120]!r}\n'
        )
        sys.exit(1)
    if 'content' not in d:
        # GitHub returns 200 without a content field for some non-blob
        # entries (e.g. directory listings). Caller interprets the empty
        # string as absent, which is the right semantic here.
        return ''
    try:
        return base64.b64decode(d['content']).decode('utf-8')
    except (ValueError, UnicodeDecodeError) as e:
        sys.stderr.write(f'github.sh: failed to decode {path}: {e}\n')
        sys.exit(1)

print(f'=== Issue Templates ({len(ordered)} found) ===')
print('Priority order: directory templates first, then legacy. Empty files are treated as absent.')
print('For YAML form templates (.yml/.yaml), map generated content into the declared form fields — do not write freeform markdown.')
print()

shown = 0
for path in ordered:
    body = get_file(path)
    if not body.strip():
        continue  # treat empty as absent
    shown += 1
    print(f'--- {path} ---')
    print(body.rstrip())
    print()

if shown == 0:
    print('All matched template files were empty — treat as absent.')
"
        ;;
    templates-pr)
        # Enumerate PR templates on the default branch, priority order (case-insensitive):
        #   1. .github/PULL_REQUEST_TEMPLATE.md
        #   2. .github/PULL_REQUEST_TEMPLATE/ directory (multi-template layout)
        #   3. docs/PULL_REQUEST_TEMPLATE.md
        #   4. PULL_REQUEST_TEMPLATE.md at repo root
        # Empty files are treated as absent.
        DEFAULT_BRANCH=$(fetch "/repos/${REPO}" | python3 -c "import sys,json; print(json.load(sys.stdin)['default_branch'])")
        BRANCH_SHA=$(fetch "/repos/${REPO}/git/refs/heads/${DEFAULT_BRANCH}" | python3 -c "import sys,json; print(json.load(sys.stdin)['object']['sha'])")

        export REPO API DEFAULT_BRANCH
        fetch "/repos/${REPO}/git/trees/${BRANCH_SHA}?recursive=1" | python3 -c "
import sys, json, os, subprocess, base64

API = os.environ['API']
REPO = os.environ['REPO']
REF = os.environ['DEFAULT_BRANCH']

tree = json.load(sys.stdin).get('tree', [])
paths = [item['path'] for item in tree if item.get('type') == 'blob']

def ci_match(path, candidate):
    return path.lower() == candidate.lower()

# Single-file candidates in priority order
single_candidates = [
    '.github/PULL_REQUEST_TEMPLATE.md',
    'docs/PULL_REQUEST_TEMPLATE.md',
    'PULL_REQUEST_TEMPLATE.md',
]
single_found = []
for cand in single_candidates:
    for p in paths:
        if ci_match(p, cand):
            single_found.append(p)
            break

# Multi-template directory
dir_templates = sorted([
    p for p in paths
    if p.lower().startswith('.github/pull_request_template/')
    and p.lower().endswith('.md')
])

# Combine: single at root of .github first, then directory templates, then fallbacks
ordered = []
for p in single_found:
    if p.lower().startswith('.github/pull_request_template.md'):
        ordered.append(p)
ordered.extend(dir_templates)
for p in single_found:
    if not p.lower().startswith('.github/pull_request_template.md'):
        ordered.append(p)

if not ordered:
    print('No PR templates found.')
    sys.exit(0)

def get_file(path):
    cmd = ['curl', '-sf', '-H', 'Accept: application/vnd.github+json',
           f'{API}/repos/{REPO}/contents/{path}?ref={REF}']
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
    except OSError as e:
        sys.stderr.write(f'github.sh: failed to invoke curl for {path}: {e}\n')
        sys.exit(1)
    if result.returncode != 0:
        sys.stderr.write(
            f'github.sh: curl failed for {path} (rc={result.returncode}); '
            f'stderr: {result.stderr.strip()}\n'
        )
        sys.exit(1)
    body = result.stdout or ''
    if not body.strip():
        sys.stderr.write(f'github.sh: empty response for {path}\n')
        sys.exit(1)
    try:
        d = json.loads(body)
    except json.JSONDecodeError as e:
        sys.stderr.write(
            f'github.sh: non-JSON response for {path}: {e}; '
            f'first 120 bytes: {body[:120]!r}\n'
        )
        sys.exit(1)
    if 'content' not in d:
        # GitHub returns 200 without a content field for some non-blob
        # entries (e.g. directory listings). Caller interprets the empty
        # string as absent, which is the right semantic here.
        return ''
    try:
        return base64.b64decode(d['content']).decode('utf-8')
    except (ValueError, UnicodeDecodeError) as e:
        sys.stderr.write(f'github.sh: failed to decode {path}: {e}\n')
        sys.exit(1)

print(f'=== PR Templates ({len(ordered)} found) ===')
print('Priority order shown above. Empty files are treated as absent.')
print('If multiple templates exist, pick the one whose filename/title best matches the change type; otherwise the first listed.')
print('Do not strip or reorder template sections — fill them in.')
print()

shown = 0
for path in ordered:
    body = get_file(path)
    if not body.strip():
        continue  # treat empty as absent
    shown += 1
    print(f'--- {path} ---')
    print(body.rstrip())
    print()

if shown == 0:
    print('All matched template files were empty — treat as absent.')
"
        ;;
    *)
        echo "GitHub API helper for good-oss-citizen tile"
        echo ""
        echo "Usage: $0 <command> <owner/repo> [args]"
        echo ""
        echo "Commands:"
        echo "  repo-scan <owner/repo>               Scan repo for policy/convention files"
        echo "  issue <owner/repo> <number>           Get issue details + labels + assignee"
        echo "  issue-comments <owner/repo> <number>  Get all comments on an issue"
        echo "  check-claim <owner/repo> <number>     DEPRECATED: use issue-comments instead"
        echo "  issues-open <owner/repo>              List open issues with labels"
        echo "  issues-closed <owner/repo>            List closed issues with reasons"
        echo "  prs-closed <owner/repo>               List closed/merged PRs"
        echo "  pr-history <owner/repo>               Closed PRs with rejection feedback"
        echo "  pr-comments <owner/repo> <number>     Get comments on a PR"
        echo "  pr-stats <owner/repo>                 PR size statistics from merged PRs"
        echo "  commit-conventions <owner/repo>       Detect commit message format"
        echo "  branch-conventions <owner/repo>       Detect branch naming pattern"
        echo "  ai-policy <owner/repo>                Fetch AI policy files for LLM interpretation"
        echo "  disclosure-format <owner/repo>        Extract AI disclosure template"
        echo "  conventions-config <owner/repo>        Read .editorconfig, .pre-commit-config, pyproject.toml tool sections"
        echo "  contributing-requirements <owner/repo> Fetch CONTRIBUTING.md for LLM interpretation"
        echo "  codeowners <owner/repo>                Parse CODEOWNERS file"
        echo "  legal <owner/repo>                     Check DCO, CLA, license, sign-off patterns"
        echo "  file <owner/repo> <path>               Get file contents"
        echo "  templates-issue <owner/repo>           Fetch all issue templates with contents"
        echo "  templates-pr <owner/repo>              Fetch all PR templates with contents"
        exit 1
        ;;
esac
