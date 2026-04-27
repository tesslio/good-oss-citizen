# Synthetic filled PR body

## Summary (required)
Describe the problem and fix in 2–5 bullets:
- Fixes token handling in the message bridge.
- Keeps binary payloads out of prompt-visible text.

## Compatibility / Migration (required)
- Backward compatible? (Yes/No) Yes
- Config/env changes? (Yes/No) No
- Migration needed? (Yes/No) No
- If yes, exact upgrade steps: N/A

## User-visible changes (required)
List user-visible changes (including defaults/config). If none, write `None`.
None.

## Environment (required)
- OS: Linux
- Node: 22

New permissions/capabilities? (Yes/No) No

If this PR fixes a plugin beta-release blocker, title it fix(<plugin-id>): beta blocker - <summary> and link the matching Beta blocker: <plugin-name> - <summary> issue labeled beta-blocker. Contributors cannot label PRs, so the title is the PR-side signal for maintainers and automation.
