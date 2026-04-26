"""Smoke test: every github.sh command emits a valid JSON envelope.

Exercises all 22 commands against a stable public test repo and asserts:
  - stdout is parseable as JSON
  - the envelope has the contract keys (command, ok, data, warnings, errors)
  - each key has the correct type
  - exit code matches `ok` (0 for ok=true, non-zero for ok=false)

Pass `--repo OWNER/REPO` to override the target. Defaults to
`tesslio/good-oss-citizen` (this project's upstream — stable enough
for CI). The chosen repo just needs to exist and respond to public
read APIs; no specific contents are required because the test grades
the envelope shape, not the data inside it.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
GITHUB_SH = REPO_ROOT / "tiles" / "good-oss-citizen" / "skills" / "recon" / "scripts" / "bash" / "github.sh"

# (command-name, args-template, expected-ok). args-template uses {repo} and
# {issue_number}/{pr_number}/{file_path} placeholders.
COMMANDS = [
    ("repo-scan", ["{repo}"], True),
    ("issue", ["{repo}", "{issue_number}"], True),
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

    expected_keys = {"command", "ok", "data", "warnings", "errors"}
    missing = expected_keys - env.keys()
    if missing:
        raise AssertionError(f"{cmd_name}: missing keys {missing} (got {set(env)})")

    if not isinstance(env["command"], str):
        raise AssertionError(f"{cmd_name}: 'command' must be string, got {type(env['command']).__name__}")
    if not isinstance(env["ok"], bool):
        raise AssertionError(f"{cmd_name}: 'ok' must be bool, got {type(env['ok']).__name__}")
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

    placeholders = {
        "repo": args.repo,
        "issue_number": args.issue_number,
        "pr_number": args.pr_number,
        "file_path": args.file_path,
    }

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

        # Exit code must agree with ok.
        expected_rc = 0 if expected_ok else 1
        if rc != expected_rc:
            msg = f"{cmd_name}: exit code {rc} disagrees with ok={env['ok']} (expected {expected_rc})"
            failed.append(msg)
            print(f"FAIL {msg}", file=sys.stderr)
            continue

        warn = " WARN" if env["warnings"] else ""
        print(f"PASS {cmd_name}{warn}")

    if failed:
        print(f"\n{len(failed)} of {len(COMMANDS)} commands failed", file=sys.stderr)
        return 1
    print(f"\nAll {len(COMMANDS)} commands emitted valid envelopes against {args.repo}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
