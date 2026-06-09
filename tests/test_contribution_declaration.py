"""Unit test: the contribution-declaration gate check classifies PR bodies.

Exercises check_contribution_declaration.py — the deterministic gate the
`install-gate` skill vendors into consumer repos — against hand-written
PR-body fixtures and asserts:
  - evaluate() returns the expected verdict and the two boolean signals
  - the CLI exit code matches the verdict (0 pass / 1 fail / 2 error)
  - all three input paths agree (--body-file, $PR_BODY, stdin)
  - a missing --body-file is a clean internal error (ok=false, exit 2)

Per `rules/testing-standards.md` every fixture is fixed and built in this
file — no network, no random data, no binary fixtures. The script is
stdlib-only, so this test needs nothing beyond the standard library and
runs offline.
"""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT_DIR = (
    REPO_ROOT
    / "plugins"
    / "good-oss-citizen"
    / "skills"
    / "install-gate"
    / "templates"
)
SCRIPT = SCRIPT_DIR / "check_contribution_declaration.py"
sys.path.insert(0, str(SCRIPT_DIR))
import check_contribution_declaration as ccd  # noqa: E402

# (name, body, verdict, ai_disclosure, no_ai_declaration)
CASES = [
    (
        "heading-disclosure-with-content",
        "## Summary\nFix the bug.\n\n## AI Disclosure\nDrafted with Claude; logic human-reviewed.\n",
        "pass", True, False,
    ),
    (
        "bold-disclosure-colon-inside-markers",
        "Summary text.\n\n**AI Disclosure:** Drafted with an AI agent, reviewed by me.\n",
        "pass", True, False,
    ),
    (
        "bold-disclosure-then-section-content",
        "**AI Disclosure**\n\nPrepared with AI assistance, then human-verified.\n",
        "pass", True, False,
    ),
    (
        "plain-label-with-colon",
        "AI Disclosure: prepared with an AI coding agent.\n",
        "pass", True, False,
    ),
    (
        "checked-no-ai-box-lowercase",
        "## Summary\nManual fix.\n\n- [x] This contribution was written without AI assistance.\n",
        "pass", False, True,
    ),
    (
        "checked-no-ai-box-uppercase",
        "- [X] No AI was used.\n",
        "pass", False, True,
    ),
    (
        "freehand-no-ai-statement",
        "I wrote this PR without AI assistance, by hand.\n",
        "pass", False, True,
    ),
    (
        "no-declaration-at-all",
        "## Summary\nJust a small fix, nothing else to declare.\n",
        "fail", False, False,
    ),
    (
        "empty-disclosure-heading-no-content",
        "## AI Disclosure\n\n## Testing\nRan the suite.\n",
        "fail", False, False,
    ),
    (
        "unchecked-no-ai-box-is-template-default",
        "- [ ] This contribution was written without AI assistance.\n",
        "fail", False, False,
    ),
    (
        "disclosure-only-inside-html-comment",
        "<!-- ## AI Disclosure: fill this in if AI-assisted -->\nJust a fix.\n",
        "fail", False, False,
    ),
    (
        "disclosure-only-inside-code-fence",
        "Example to follow:\n```\n## AI Disclosure\nprepared with AI\n```\nNothing real here.\n",
        "fail", False, False,
    ),
    (
        "bare-prose-mention-is-not-a-disclosure",
        "The AI Disclosure section is required by our policy.\n",
        "fail", False, False,
    ),
    (
        "empty-body",
        "",
        "fail", False, False,
    ),
    (
        "ai-assisted-checkbox-without-disclosure-fails",
        "## Summary\nx\n\n- [x] This contribution is AI-assisted.\n",
        "fail", False, False,
    ),
]


def check_evaluate(failures: list[str]) -> None:
    for name, body, verdict, ai, no_ai in CASES:
        result = ccd.evaluate(body)
        if result["verdict"] != verdict:
            failures.append(
                f"evaluate[{name}]: verdict={result['verdict']!r} expected {verdict!r}"
            )
        if result["ai_disclosure"] != ai:
            failures.append(
                f"evaluate[{name}]: ai_disclosure={result['ai_disclosure']} expected {ai}"
            )
        if result["no_ai_declaration"] != no_ai:
            failures.append(
                f"evaluate[{name}]: no_ai_declaration={result['no_ai_declaration']} expected {no_ai}"
            )
        if not result["reasons"]:
            failures.append(f"evaluate[{name}]: reasons[] must never be empty")


def run_cli(args: list[str], *, stdin: str | None = None, env: dict | None = None):
    proc = subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        capture_output=True,
        text=True,
        input=stdin,
        env=env,
        timeout=30,
    )
    return proc.returncode, proc.stdout, proc.stderr


def check_cli_exit_codes(failures: list[str]) -> None:
    """Exit code must encode the verdict so CI can gate on it directly."""
    for name, body, verdict, _ai, _no_ai in CASES:
        expected_rc = 0 if verdict == "pass" else 1
        with tempfile.NamedTemporaryFile(
            "w", suffix=".md", delete=False, encoding="utf-8"
        ) as handle:
            handle.write(body)
            body_path = handle.name
        try:
            rc, out, _err = run_cli(["--body-file", body_path])
        finally:
            Path(body_path).unlink()
        try:
            env = json.loads(out)
        except json.JSONDecodeError as exc:
            failures.append(f"cli[{name}]: stdout not JSON: {exc}; out={out[:200]!r}")
            continue
        if env["data"]["verdict"] != verdict:
            failures.append(
                f"cli[{name}]: verdict={env['data']['verdict']!r} expected {verdict!r}"
            )
        if rc != expected_rc:
            failures.append(
                f"cli[{name}]: exit {rc} expected {expected_rc} (verdict {verdict})"
            )


def check_input_paths_agree(failures: list[str]) -> None:
    """--body-file, $PR_BODY, and stdin must produce the same verdict."""
    body = "## AI Disclosure\nPrepared with an AI agent, reviewed by a human.\n"
    with tempfile.NamedTemporaryFile(
        "w", suffix=".md", delete=False, encoding="utf-8"
    ) as handle:
        handle.write(body)
        body_path = handle.name
    try:
        rc_file, _o, _e = run_cli(["--body-file", body_path])
        rc_env, _o, _e = run_cli([], env={"PR_BODY": body, "PATH": _PATH()})
        rc_stdin, _o, _e = run_cli([], stdin=body)
    finally:
        Path(body_path).unlink()
    if not (rc_file == rc_env == rc_stdin == 0):
        failures.append(
            f"input-paths disagree: file={rc_file} env={rc_env} stdin={rc_stdin} (all expected 0)"
        )


def check_missing_body_file_is_error(failures: list[str]) -> None:
    rc, out, _err = run_cli(["--body-file", "/nonexistent/path/to/body.md"])
    try:
        env = json.loads(out)
    except json.JSONDecodeError as exc:
        failures.append(f"missing-body-file: stdout not JSON: {exc}")
        return
    if env["ok"] is not False:
        failures.append("missing-body-file: ok must be false on read error")
    if not env["errors"]:
        failures.append("missing-body-file: errors[] must be populated on read error")
    if rc != 2:
        failures.append(f"missing-body-file: exit {rc} expected 2")


def _PATH() -> str:
    import os

    return os.environ.get("PATH", "")


def main() -> int:
    if not SCRIPT.is_file():
        print(f"FAIL: detection script not found at {SCRIPT}", file=sys.stderr)
        return 2

    failures: list[str] = []
    check_evaluate(failures)
    check_cli_exit_codes(failures)
    check_input_paths_agree(failures)
    check_missing_body_file_is_error(failures)

    if failures:
        for failure in failures:
            print(f"FAIL {failure}", file=sys.stderr)
        print(f"\n{len(failures)} check(s) failed", file=sys.stderr)
        return 1
    print(f"PASS all {len(CASES)} classification cases + CLI/input/error checks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
