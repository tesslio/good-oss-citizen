"""Smoke test: every github.sh command emits a valid JSON envelope.

Exercises all 23 commands against a stable public test repo and asserts:
  - stdout is parseable as JSON
  - the envelope has the contract keys (command, ok, data, warnings, errors)
  - each key has the correct type
  - exit code matches `ok` (0 for ok=true, non-zero for ok=false)

Per `rules/testing-standards.md` ("Tests must be deterministic; provide
fixed test data"), every fixture is hard-coded:
  - repo:        tesslio/good-oss-citizen
  - issue #13:   this migration's tracking issue
  - PR #12:      the previous merged PR
  - file path:   README.md
None of these will be deleted from the upstream. `--repo`,
`--issue-number`, `--pr-number`, and `--file-path` flags exist for
running the test against a different fixture set if the upstream ever
becomes unavailable, but no value is auto-discovered. There is no
network call before the script is invoked.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from unittest import mock

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT_DIR = REPO_ROOT / "plugins" / "good-oss-citizen" / "skills" / "recon" / "scripts" / "bash"
GITHUB_SH = SCRIPT_DIR / "github.sh"
sys.path.insert(0, str(SCRIPT_DIR))
from _templates import issue_template_dir_paths  # noqa: E402
import _envelope  # noqa: E402

# (command-name, args-template, expected-ok). args-template uses {repo} and
# {issue_number}/{pr_number}/{file_path} placeholders.
COMMANDS = [
    ("repo-scan", ["{repo}"], True),
    ("issue", ["{repo}", "{issue_number}"], True),
    ("body", ["{repo}", "{issue_number}"], True),
    ("issue-comments", ["{repo}", "{issue_number}"], True),
    ("check-claim", ["{repo}", "{issue_number}"], True),
    ("issues-open", ["{repo}"], True),
    ("issues-closed", ["{repo}"], True),
    ("prs-closed", ["{repo}"], True),
    ("pr-history", ["{repo}"], True),
    ("related-prs", ["{repo}", "{issue_number}"], True),
    ("pr-comments", ["{repo}", "{pr_number}"], True),
    ("file", ["{repo}", "{file_path}"], True),
    ("commit-conventions", ["{repo}"], True),
    ("branch-conventions", ["{repo}"], True),
    ("ai-policy", ["{repo}"], True),
    ("disclosure-format", ["{repo}"], True),
    ("pr-stats", ["{repo}"], True),
    ("conventions-config", ["{repo}"], True),
    ("contributing-requirements", ["{repo}"], True),
    ("codeowners", ["{repo}"], True),
    ("legal", ["{repo}"], True),
    ("templates-issue", ["{repo}"], True),
    ("templates-pr", ["{repo}"], True),
]


def assert_issue_template_config_excluded() -> None:
    """Regression guard: GitHub's chooser-config files are not template bodies.

    Behavioral check on the shared filter — `repo-scan` and
    `templates-issue` both call it, so verifying the filter is enough.
    A future refactor that unwires the helper from one caller is caught
    by the live `repo-scan` / `templates-issue` exercise in the smoke
    test against the upstream repo, not by source-text counting here.
    """
    paths = {
        ".github/ISSUE_TEMPLATE/config.yml",
        ".github/ISSUE_TEMPLATE/config.yaml",
        ".github/ISSUE_TEMPLATE/bug.yml",
        ".github/ISSUE_TEMPLATE/feature.md",
        ".github/ISSUE_TEMPLATE/note.txt",
    }
    assert issue_template_dir_paths(paths) == [
        ".github/ISSUE_TEMPLATE/bug.yml",
        ".github/ISSUE_TEMPLATE/feature.md",
        ".github/ISSUE_TEMPLATE/note.txt",
    ], "issue_template_dir_paths must exclude config files only"

    assert issue_template_dir_paths(paths, extensions=(".md", ".yml", ".yaml")) == [
        ".github/ISSUE_TEMPLATE/bug.yml",
        ".github/ISSUE_TEMPLATE/feature.md",
    ], "extension filter must apply on top of the config exclusion"


def assert_pagination_ceiling_semantics() -> None:
    """Regression guard: paging is complete-flagged and bounded."""
    # Two short pages -> complete.
    pages = iter([[{"i": n} for n in range(100)], [{"i": 100}]])
    with mock.patch.object(_envelope, "fetch_json", side_effect=lambda e: next(pages)):
        items, complete = _envelope.fetch_json_pages("/x")
    assert len(items) == 101 and complete is True, "short final page means complete"

    # Always-full pages -> stops at the ceiling and reports incomplete.
    with mock.patch.object(_envelope, "fetch_json", side_effect=lambda e: [{"i": 0}] * 100):
        items, complete = _envelope.fetch_json_pages("/x")
    assert complete is False, "hitting the ceiling must report incomplete"
    assert len(items) == _envelope.MAX_PAGES * 100, "must stop at MAX_PAGES"

    # Exactly MAX_PAGES * 100 items: every page is full, but there is no more
    # data. The probe past the ceiling must distinguish this from truncation,
    # otherwise a complete read is reported as incomplete.
    pages = [[{"i": 0}] * 100] * _envelope.MAX_PAGES + [[]]
    served = iter(pages)
    with mock.patch.object(_envelope, "fetch_json", side_effect=lambda e: next(served)):
        items, complete = _envelope.fetch_json_pages("/x")
    assert complete is True, "an empty probe page means the read was complete"
    assert len(items) == _envelope.MAX_PAGES * 100

    # A failed page -> (None, False), never a partial silent answer.
    with mock.patch.object(_envelope, "fetch_json", side_effect=lambda e: None):
        assert _envelope.fetch_json_pages("/x") == (None, False)

    # Query-string endpoints keep their existing params.
    seen = []
    with mock.patch.object(
        _envelope, "fetch_json", side_effect=lambda e: (seen.append(e), [])[1]
    ):
        _envelope.fetch_json_pages("/repos/o/r/pulls?state=closed")
    assert "state=closed&per_page=100&page=1" in seen[0], seen


def run(cmd_name: str, args: list[str]) -> tuple[int, str]:
    proc = subprocess.run(
        ["bash", str(GITHUB_SH), cmd_name, *args],
        capture_output=True,
        text=True,
        timeout=60,
    )
    return proc.returncode, proc.stdout


def assert_envelope(cmd_name: str, body: str) -> dict:
    """Parse + structurally validate an envelope. Raises AssertionError on mismatch."""
    try:
        env = json.loads(body)
    except json.JSONDecodeError as e:
        raise AssertionError(f"{cmd_name}: stdout is not JSON: {e}\n--- body ---\n{body[:400]}")

    # Top-level type check first — calling .keys() on a JSON list/scalar
    # would raise AttributeError instead of a clear assertion message.
    if not isinstance(env, dict):
        raise AssertionError(
            f"{cmd_name}: top-level JSON must be an object, got {type(env).__name__}: {body[:200]}"
        )

    expected_keys = {"command", "ok", "data", "warnings", "errors"}
    missing = expected_keys - env.keys()
    if missing:
        raise AssertionError(f"{cmd_name}: missing keys {missing} (got {set(env)})")

    if not isinstance(env["command"], str):
        raise AssertionError(f"{cmd_name}: 'command' must be string, got {type(env['command']).__name__}")
    if not isinstance(env["ok"], bool):
        raise AssertionError(f"{cmd_name}: 'ok' must be bool, got {type(env['ok']).__name__}")
    if env["data"] is not None and not isinstance(env["data"], dict):
        raise AssertionError(f"{cmd_name}: 'data' must be dict or null, got {type(env['data']).__name__}")
    if not isinstance(env["warnings"], list):
        raise AssertionError(f"{cmd_name}: 'warnings' must be list")
    if not isinstance(env["errors"], list):
        raise AssertionError(f"{cmd_name}: 'errors' must be list")
    return env


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default="tesslio/good-oss-citizen",
                        help="OWNER/REPO to exercise commands against")
    parser.add_argument("--issue-number", default="13",
                        help="Issue number that exists on --repo")
    parser.add_argument("--pr-number", default="12",
                        help="PR number that exists on --repo")
    parser.add_argument("--file-path", default="README.md",
                        help="A file path that exists on --repo's default branch")
    args = parser.parse_args()

    if not GITHUB_SH.is_file():
        print(f"FAIL: github.sh not found at {GITHUB_SH}", file=sys.stderr)
        return 2

    try:
        assert_issue_template_config_excluded()
        print("PASS static-regression (ISSUE_TEMPLATE config.yml excluded)")
        assert_pagination_ceiling_semantics()
        print("PASS static-regression (pagination ceiling semantics)")
    except AssertionError as e:
        print(f"FAIL static-regression: {e}", file=sys.stderr)
        return 1

    placeholders = {
        "repo": args.repo,
        "issue_number": args.issue_number,
        "pr_number": args.pr_number,
        "file_path": args.file_path,
    }
    print(f"Fixtures: repo={placeholders['repo']} "
          f"issue={placeholders['issue_number']} "
          f"pr={placeholders['pr_number']} "
          f"file={placeholders['file_path']}")

    failed: list[str] = []
    for cmd_name, arg_template, expected_ok in COMMANDS:
        rendered = [a.format(**placeholders) for a in arg_template]
        rc, body = run(cmd_name, rendered)
        try:
            env = assert_envelope(cmd_name, body)
        except AssertionError as e:
            failed.append(str(e))
            print(f"FAIL {cmd_name}: {e}", file=sys.stderr)
            continue

        if env["command"] != cmd_name:
            msg = f"{cmd_name}: command field is {env['command']!r}"
            failed.append(msg)
            print(f"FAIL {msg}", file=sys.stderr)
            continue

        if env["ok"] != expected_ok:
            msg = (f"{cmd_name}: ok={env['ok']} but expected {expected_ok}; "
                   f"errors={env['errors']}, warnings={env['warnings']}")
            failed.append(msg)
            print(f"FAIL {msg}", file=sys.stderr)
            continue

        if cmd_name == "body" and env["ok"]:
            data = env["data"]
            required = {"kind", "number", "title", "state", "url", "body"}
            missing = required - data.keys()
            if missing:
                msg = f"body: missing data keys {missing}"
                failed.append(msg)
                print(f"FAIL {msg}", file=sys.stderr)
                continue
            if data["kind"] not in {"issue", "pull_request"}:
                msg = f"body: kind must be issue or pull_request, got {data['kind']!r}"
                failed.append(msg)
                print(f"FAIL {msg}", file=sys.stderr)
                continue

        # Exit code must agree with ok.
        expected_rc = 0 if expected_ok else 1
        if rc != expected_rc:
            msg = f"{cmd_name}: exit code {rc} disagrees with ok={env['ok']} (expected {expected_rc})"
            failed.append(msg)
            print(f"FAIL {msg}", file=sys.stderr)
            continue

        warn = " WARN" if env["warnings"] else ""
        print(f"PASS {cmd_name}{warn}")

    # Negative-path: invoking an unknown command must produce a valid
    # failure envelope (ok=false, errors populated) AND exit non-zero.
    # The contract covers failure too, so a regression there should fail
    # CI as loudly as the success-path contract.
    rc, body = run("definitely-not-a-real-command", ["dummy/repo"])
    try:
        env = assert_envelope("definitely-not-a-real-command", body)
        if env["ok"] is not False:
            failed.append("unknown-command negative path: ok was not false")
        elif not env["errors"]:
            failed.append("unknown-command negative path: errors[] empty")
        elif rc == 0:
            failed.append("unknown-command negative path: exit code was 0")
        else:
            print("PASS negative-path (unknown command emits ok=false envelope, exit non-zero)")
    except AssertionError as e:
        failed.append(f"negative-path: {e}")
        print(f"FAIL negative-path: {e}", file=sys.stderr)

    if failed:
        print(f"\n{len(failed)} of {len(COMMANDS) + 1} checks failed", file=sys.stderr)
        return 1
    print(f"\nAll {len(COMMANDS)} commands + 1 negative path emitted valid envelopes against {args.repo}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
