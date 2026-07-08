---
name: install-gate
description: >
  Scaffold the good-oss-citizen contribution gate into a consumer
  repository: a `pull_request_target` GitHub Actions check that fails any
  pull request whose description lacks a contribution declaration — an "AI
  Disclosure" section or an explicit "no AI assistance" statement — plus the
  vendored detection script, a PR template, and the tessl.json dependency
  entry. The gate enforces an outcome (AI use is disclosed) on the PR side,
  where it cannot be bypassed; it does not, and cannot, prove a tool ran.
  Use when a maintainer wants to add, install, set up, scaffold, enable, or
  wire up a contribution gate / a PR check that requires good-oss-citizen or
  AI-use disclosure before contributing.
---

# Install Gate Skill

Process steps in order. Do not skip ahead.

This skill scaffolds the good-oss-citizen contribution gate into a consumer repository — each step depends on the previous one; do not parallelize.

## Step 1 — Run Preflight Checks

```bash
.tessl/plugins/tessl-labs/good-oss-citizen/skills/install-gate/preflight.sh
```

Runs every precondition (git worktree, python3, GitHub CLI install + auth, installed-plugin templates, origin remote, local + remote branch clear) and returns one JSON object: `{"ok": bool, "failures": [...], "warnings": [...]}`.

- **Exit 0, empty `failures`** — every precondition passed; proceed to Step 2.
- **Exit 1, populated `failures`** — report each failure's `reason` verbatim and stop. Every failure carries a concrete recovery command.
- **Non-empty `warnings`** — informational only; never affects `ok` or the exit code. Report each `reason` verbatim and remember it for Step 7's PR body. Do not stop; proceed to Step 2.

## Step 2 — Refuse Overwrite

If either `.github/workflows/contribution-gate.yml` or `.github/scripts/check_contribution_declaration.py` already exists in the repo, stop and report that a gate is already installed. Do not overwrite either file — a partial prior install is deliberate state the skill must not destroy. An existing pull-request template is NOT a blocker: Step 4 leaves it in place and warns instead. If neither gate file exists, proceed immediately to Step 3.

## Step 3 — Create Feature Branch

```bash
.tessl/plugins/tessl-labs/good-oss-citizen/skills/install-gate/branch.sh
```

Creates `feat/add-good-oss-citizen-gate` from origin's default branch (resolved from the remote, not the caller's current HEAD), and emits a JSON object `{"state":"created|already-on-branch","branch":...,"base":...}`. Idempotent: a no-op if already on the branch. Proceed immediately to Step 4.

## Step 4 — Scaffold Gate Files

```bash
.tessl/plugins/tessl-labs/good-oss-citizen/skills/install-gate/scaffold.sh
```

Writes `.github/workflows/contribution-gate.yml` and the vendored `.github/scripts/check_contribution_declaration.py`, adds `.github/PULL_REQUEST_TEMPLATE.md` only when the repo has no PR template anywhere GitHub looks (otherwise it leaves the existing one and emits a warning), and ensures `tessl.json` declares the `tessl-labs/good-oss-citizen` dependency (created if absent, added if missing, never overwriting an existing pin). Atomic: it validates templates, version, and `tessl.json` parseability before writing anything, and rolls back every file it created (restoring `tessl.json`) if a later step fails — so a failed run never leaves a partial install for Step 2 to refuse on re-run. Emits a JSON summary with the written paths, the `tessl_json` state, and a `warnings` array; exits non-zero with a stderr diagnostic on failure. Remember any warnings for Step 7. Proceed immediately to Step 5.

## Step 5 — Commit

```bash
.tessl/plugins/tessl-labs/good-oss-citizen/skills/install-gate/commit.sh
```

Stages the gate workflow, the vendored detector, `tessl.json`, and the PR template (only when scaffold created it) and commits with the canonical message `ci(gate): add good-oss-citizen contribution gate`. Idempotent: emits `{"state": "no-op", …}` when the working tree already matches a prior successful run. If a pre-commit hook rejects the commit, the script exits non-zero — fix the hook's finding and re-run; do not `--no-verify`. Proceed immediately to Step 6.

## Step 6 — Push

```bash
.tessl/plugins/tessl-labs/good-oss-citizen/skills/install-gate/push.sh
```

Pushes `feat/add-good-oss-citizen-gate` to origin with upstream tracking. Idempotent: emits `{"state": "up-to-date", …}` if origin already matches local HEAD. Proceed immediately to Step 7.

## Step 7 — Open PR

`gh pr create` with title `ci(gate): add good-oss-citizen contribution gate` and a body that follows the content blocks defined at:

```text
.tessl/plugins/tessl-labs/good-oss-citizen/skills/install-gate/PR_BODY_TEMPLATE.md
```

Return the PR URL. If Step 1 or Step 4 emitted any warnings, surface them inline in your user-facing summary too (not only in the PR body) so the maintainer sees them immediately. The PR body MUST tell the maintainer to mark the gate's status check as a required check in branch protection — without that, the gate runs but does not block merges. Finish here — the maintainer reviews, marks the check required, acts on any warnings, and merges.
