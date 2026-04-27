# Synthetic PR template

## Change type (required)
Select all that apply:
- [ ] Bug fix
- [ ] Security hardening
- [ ] Documentation

## Summary (required)
Describe the problem and fix in 2–5 bullets:

## Security Impact (required)
List security-sensitive behavior changes. If none, write `None`.

## Compatibility / Migration (required)
- Backward compatible? (Yes/No)
- Config/env changes? (Yes/No)
- Migration needed? (Yes/No)
- If yes, exact upgrade steps:

## Repro / Verification (required)
For bug fixes or regressions, explain why this happened, not just what changed. Otherwise write `N/A`. If the cause is unclear, write `Unknown`.

## User-visible changes (required)
List user-visible changes (including defaults/config). If none, write `None`.

## Environment (required)
- OS:
- Node:

## Human verification (required)
Describe how a human reviewed the change.

New permissions/capabilities? (Yes/No)

If this PR fixes a plugin beta-release blocker, title it fix(<plugin-id>): beta blocker - <summary> and link the matching Beta blocker: <plugin-name> - <summary> issue labeled beta-blocker. Contributors cannot label PRs, so the title is the PR-side signal for maintainers and automation.
