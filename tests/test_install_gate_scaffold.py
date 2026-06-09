"""Integration test: the install-gate installer scripts behave correctly.

Exercises the deterministic helper scripts the `install-gate` skill ships —
`scaffold.sh`, `commit.sh`, `push.sh`, and `preflight.sh` — against throwaway
git repositories, asserting their JSON contracts, file effects, idempotency,
atomic rollback, and guard conditions.

Per `rules/testing-standards.md`: every fixture is built programmatically in
setup (no binary fixtures, no network), each test runs in its own temporary
git repo (no shared mutable state), and the fake installed-plugin version is a
fixed string so assertions are deterministic. `push.sh` is exercised against a
local bare repository standing in for `origin`, so no network is needed.

Run: python3 tests/test_install_gate_scaffold.py
"""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
GATE_SRC = REPO_ROOT / "plugins" / "good-oss-citizen" / "skills" / "install-gate"
TEMPLATES = GATE_SRC / "templates"
FIXED_VERSION = "9.9.9"
DEP = "tessl-labs/good-oss-citizen"
BRANCH = "feat/add-good-oss-citizen-gate"
INSTALL_REL = ".tessl/plugins/tessl-labs/good-oss-citizen"


def git(repo: Path, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        capture_output=True, text=True, timeout=30, check=False,
    )


def run_script(repo: Path, name: str) -> tuple[int, str, str]:
    proc = subprocess.run(
        ["bash", str(GATE_SRC / name)],
        cwd=str(repo), capture_output=True, text=True, timeout=60, check=False,
    )
    return proc.returncode, proc.stdout, proc.stderr


def make_consumer(root: Path, *, version: str = FIXED_VERSION) -> Path:
    """A fresh git repo with the install-gate plugin 'installed' under .tessl/plugins."""
    repo = root / "consumer"
    repo.mkdir()
    git(repo, "init", "-q")
    git(repo, "config", "user.email", "t@example.com")
    git(repo, "config", "user.name", "Test")
    git(repo, "config", "commit.gpgsign", "false")
    (repo / ".gitignore").write_text(".tessl/\n__pycache__/\n", encoding="utf-8")
    (repo / "README.md").write_text("# consumer\n", encoding="utf-8")
    git(repo, "add", ".gitignore", "README.md")
    git(repo, "commit", "-qm", "baseline")

    install = repo / INSTALL_REL / "skills" / "install-gate"
    (install / "templates").mkdir(parents=True)
    (repo / INSTALL_REL / ".tessl-plugin").mkdir(parents=True)
    (repo / INSTALL_REL / ".tessl-plugin" / "plugin.json").write_text(
        json.dumps({"name": DEP, "version": version}) + "\n", encoding="utf-8"
    )
    for tpl in ("contribution-gate.yml", "check_contribution_declaration.py",
                "PULL_REQUEST_TEMPLATE.md"):
        (install / "templates" / tpl).write_text(
            (TEMPLATES / tpl).read_text(encoding="utf-8"), encoding="utf-8"
        )
    return repo


def on_branch(repo: Path) -> None:
    git(repo, "checkout", "-q", "-b", BRANCH)


def fail(failures: list[str], msg: str) -> None:
    failures.append(msg)


def test_scaffold_fresh(failures: list[str]) -> None:
    with tempfile.TemporaryDirectory() as d:
        repo = make_consumer(Path(d))
        rc, out, err = run_script(repo, "scaffold.sh")
        if rc != 0:
            return fail(failures, f"scaffold_fresh: exit {rc}, stderr={err[:200]}")
        data = json.loads(out)
        if data["tessl_json"]["state"] != "created":
            fail(failures, f"scaffold_fresh: tessl_json state {data['tessl_json']['state']!r} != created")
        if data["tessl_json"]["version"] != FIXED_VERSION:
            fail(failures, f"scaffold_fresh: version {data['tessl_json']['version']!r} != {FIXED_VERSION}")
        if data["pr_template"]["state"] != "created":
            fail(failures, "scaffold_fresh: pr_template not created")
        for rel in (".github/workflows/contribution-gate.yml",
                    ".github/scripts/check_contribution_declaration.py",
                    ".github/PULL_REQUEST_TEMPLATE.md", "tessl.json"):
            if not (repo / rel).is_file():
                fail(failures, f"scaffold_fresh: missing {rel}")
        tj = json.loads((repo / "tessl.json").read_text())
        if tj["dependencies"].get(DEP, {}).get("version") != FIXED_VERSION:
            fail(failures, "scaffold_fresh: tessl.json dependency not written correctly")


def test_scaffold_adds_missing_dep(failures: list[str]) -> None:
    with tempfile.TemporaryDirectory() as d:
        repo = make_consumer(Path(d))
        (repo / "tessl.json").write_text(
            json.dumps({"name": "proj", "dependencies": {"other/dep": {"version": "2.0.0"}}}) + "\n",
            encoding="utf-8")
        rc, out, _ = run_script(repo, "scaffold.sh")
        if rc != 0:
            return fail(failures, f"scaffold_adds_missing_dep: exit {rc}")
        if json.loads(out)["tessl_json"]["state"] != "updated":
            fail(failures, "scaffold_adds_missing_dep: state != updated")
        tj = json.loads((repo / "tessl.json").read_text())
        if "other/dep" not in tj["dependencies"]:
            fail(failures, "scaffold_adds_missing_dep: pre-existing dep was dropped")
        if tj["dependencies"].get(DEP, {}).get("version") != FIXED_VERSION:
            fail(failures, "scaffold_adds_missing_dep: dep not added")


def test_scaffold_preserves_existing_pin(failures: list[str]) -> None:
    with tempfile.TemporaryDirectory() as d:
        repo = make_consumer(Path(d))
        (repo / "tessl.json").write_text(
            json.dumps({"name": "proj", "dependencies": {DEP: {"version": "0.0.1"}}}) + "\n",
            encoding="utf-8")
        rc, out, _ = run_script(repo, "scaffold.sh")
        if rc != 0:
            return fail(failures, f"scaffold_preserves_existing_pin: exit {rc}")
        if json.loads(out)["tessl_json"]["state"] != "present":
            fail(failures, "scaffold_preserves_existing_pin: state != present")
        tj = json.loads((repo / "tessl.json").read_text())
        if tj["dependencies"][DEP]["version"] != "0.0.1":
            fail(failures, "scaffold_preserves_existing_pin: pin was overwritten")


def test_scaffold_skips_existing_pr_template(failures: list[str]) -> None:
    with tempfile.TemporaryDirectory() as d:
        repo = make_consumer(Path(d))
        (repo / ".github").mkdir()
        (repo / ".github" / "PULL_REQUEST_TEMPLATE.md").write_text("## Mine\n", encoding="utf-8")
        rc, out, _ = run_script(repo, "scaffold.sh")
        if rc != 0:
            return fail(failures, f"scaffold_skips_existing_pr_template: exit {rc}")
        data = json.loads(out)
        if data["pr_template"]["state"] != "skipped-existing":
            fail(failures, "scaffold_skips_existing_pr_template: did not skip")
        if not data["warnings"]:
            fail(failures, "scaffold_skips_existing_pr_template: no warning emitted")
        if (repo / ".github" / "PULL_REQUEST_TEMPLATE.md").read_text() != "## Mine\n":
            fail(failures, "scaffold_skips_existing_pr_template: clobbered the maintainer's template")


def test_scaffold_rollback_on_bad_tessl_json(failures: list[str]) -> None:
    with tempfile.TemporaryDirectory() as d:
        repo = make_consumer(Path(d))
        (repo / "tessl.json").write_text("{ not valid json", encoding="utf-8")
        rc, _, _ = run_script(repo, "scaffold.sh")
        if rc == 0:
            return fail(failures, "scaffold_rollback: expected non-zero exit on malformed tessl.json")
        for rel in (".github/workflows/contribution-gate.yml",
                    ".github/scripts/check_contribution_declaration.py",
                    ".github/PULL_REQUEST_TEMPLATE.md"):
            if (repo / rel).exists():
                fail(failures, f"scaffold_rollback: {rel} should not exist after rollback")
        if (repo / "tessl.json").read_text() != "{ not valid json":
            fail(failures, "scaffold_rollback: malformed tessl.json was modified")


def test_scaffold_idempotent(failures: list[str]) -> None:
    with tempfile.TemporaryDirectory() as d:
        repo = make_consumer(Path(d))
        run_script(repo, "scaffold.sh")
        rc, out, _ = run_script(repo, "scaffold.sh")
        if rc != 0:
            return fail(failures, f"scaffold_idempotent: second run exit {rc}")
        if json.loads(out)["tessl_json"]["state"] != "present":
            fail(failures, "scaffold_idempotent: second run did not report dep present")


def test_commit_flow(failures: list[str]) -> None:
    with tempfile.TemporaryDirectory() as d:
        repo = make_consumer(Path(d))
        on_branch(repo)
        run_script(repo, "scaffold.sh")
        rc, out, err = run_script(repo, "commit.sh")
        if rc != 0:
            return fail(failures, f"commit_flow: exit {rc}, stderr={err[:200]}")
        if json.loads(out)["state"] != "committed":
            fail(failures, "commit_flow: first run not 'committed'")
        files = git(repo, "show", "--name-only", "--format=", "HEAD").stdout
        for rel in (".github/workflows/contribution-gate.yml", "tessl.json"):
            if rel not in files:
                fail(failures, f"commit_flow: {rel} not in commit")
        rc2, out2, _ = run_script(repo, "commit.sh")
        if rc2 != 0 or json.loads(out2)["state"] != "no-op":
            fail(failures, "commit_flow: second run should be a no-op")


def test_commit_wrong_branch_guard(failures: list[str]) -> None:
    with tempfile.TemporaryDirectory() as d:
        repo = make_consumer(Path(d))  # stays on default branch, not BRANCH
        run_script(repo, "scaffold.sh")
        rc, _, err = run_script(repo, "commit.sh")
        if rc == 0:
            fail(failures, "commit_wrong_branch_guard: expected non-zero exit off the feature branch")
        elif "branch" not in err.lower():
            fail(failures, "commit_wrong_branch_guard: diagnostic should mention the branch")


def test_push_flow(failures: list[str]) -> None:
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        repo = make_consumer(root)
        bare = root / "origin.git"
        subprocess.run(["git", "init", "-q", "--bare", str(bare)], check=True, timeout=30)
        git(repo, "remote", "add", "origin", str(bare))
        on_branch(repo)
        run_script(repo, "scaffold.sh")
        run_script(repo, "commit.sh")
        rc, out, err = run_script(repo, "push.sh")
        if rc != 0:
            return fail(failures, f"push_flow: exit {rc}, stderr={err[:200]}")
        if json.loads(out)["state"] != "pushed":
            fail(failures, "push_flow: first run not 'pushed'")
        rc2, out2, _ = run_script(repo, "push.sh")
        if rc2 != 0 or json.loads(out2)["state"] != "up-to-date":
            fail(failures, "push_flow: second run should be 'up-to-date'")


def test_preflight_missing_templates(failures: list[str]) -> None:
    with tempfile.TemporaryDirectory() as d:
        repo = make_consumer(Path(d))
        # Remove the installed templates so the templates-present check fails.
        import shutil
        shutil.rmtree(repo / INSTALL_REL / "skills" / "install-gate" / "templates")
        rc, out, _ = run_script(repo, "preflight.sh")
        if rc == 0:
            return fail(failures, "preflight_missing_templates: expected non-zero exit")
        data = json.loads(out)
        checks = {f["check"] for f in data["failures"]}
        if "templates-present" not in checks:
            fail(failures, f"preflight_missing_templates: 'templates-present' not in failures {checks}")
        if data["ok"] is not False:
            fail(failures, "preflight_missing_templates: ok should be false")


TESTS = [
    test_scaffold_fresh,
    test_scaffold_adds_missing_dep,
    test_scaffold_preserves_existing_pin,
    test_scaffold_skips_existing_pr_template,
    test_scaffold_rollback_on_bad_tessl_json,
    test_scaffold_idempotent,
    test_commit_flow,
    test_commit_wrong_branch_guard,
    test_push_flow,
    test_preflight_missing_templates,
]


def main() -> int:
    if not GATE_SRC.is_dir():
        print(f"FAIL: install-gate scripts not found at {GATE_SRC}", file=sys.stderr)
        return 2
    failures: list[str] = []
    for test in TESTS:
        test(failures)
        if not any(f.startswith(test.__name__.replace("test_", "")) for f in failures):
            print(f"PASS {test.__name__}")
    if failures:
        for f in failures:
            print(f"FAIL {f}", file=sys.stderr)
        print(f"\n{len(failures)} check(s) failed", file=sys.stderr)
        return 1
    print(f"\nAll {len(TESTS)} installer-script tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
