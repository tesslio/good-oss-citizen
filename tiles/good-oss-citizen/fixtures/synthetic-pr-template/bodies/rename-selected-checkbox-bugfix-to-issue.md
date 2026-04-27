# Synthetic filled PR body

## Change type (required)
Select all that apply:
- [x] Issue
- [x] Security hardening
- [ ] Documentation

## Summary (required)
Describe the problem and fix in 2–5 bullets:
- Fixes token handling in the message bridge.
- Keeps binary payloads out of prompt-visible text.

## Security Impact (required)
List security-sensitive behavior changes. If none, write `None`.
Reduces prompt-injection and token-inflation exposure from binary captions.

## Compatibility / Migration (required)
- Backward compatible? (Yes/No) Yes
- Config/env changes? (Yes/No) No
- Migration needed? (Yes/No) No
- If yes, exact upgrade steps: N/A

## Repro / Verification (required)
For bug fixes or regressions, explain why this happened, not just what changed. Otherwise write `N/A`. If the cause is unclear, write `Unknown`.
The bridge treated all caption-like payloads as prompt text. Verified with unit tests and a manual binary-caption fixture.

## User-visible changes (required)
List user-visible changes (including defaults/config). If none, write `None`.
None.

## Environment (required)
- OS: Linux
- Node: 22

## Human verification (required)
Reviewed the diff, tests, and generated PR body before submission.

New permissions/capabilities? (Yes/No) No

If this PR fixes a plugin beta-release blocker, title it fix(<plugin-id>): beta blocker - <summary> and link the matching Beta blocker: <plugin-name> - <summary> issue labeled beta-blocker. Contributors cannot label PRs, so the title is the PR-side signal for maintainers and automation.
