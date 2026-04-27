# Final-verification pass on a draft PR body

I'm finalizing a pull request body before I open it. Tell me what to do before I submit. Don't post anything to GitHub.

## The repo's PR template

````markdown
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
````

## My draft body

````markdown
# Synthetic filled PR body

## Change type (required)
Select all that apply:
- [x] Bug fix
- [x] Security hardening
- [ ] Documentation

## Summary (required)
Describe the problem and fix in 2–5 bullets:
- Fixes token handling in the message bridge.
- Keeps binary payloads out of prompt-visible text.
- Replaces the legacy `messageBridge.rawCaption` export with `messageBridge.safeCaption`, which is a breaking change for plugins importing the old helper.

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
````
