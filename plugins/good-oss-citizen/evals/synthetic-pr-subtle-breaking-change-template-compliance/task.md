# Look at this open pull request body

A contributor opened this pull request. The repo's PR template and the open body are below. Take a look at the body before review and tell me what you make of it. Don't post anything to GitHub.

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
- Removes the legacy `messageBridge.rawCaption` export in favor of `messageBridge.safeCaption`; plugins still calling the old symbol will need to update their imports.

## Security Impact (required)
List security-sensitive behavior changes. If none, write `None`.
Reduces prompt-injection and token-inflation exposure from binary captions.
The bridge now normalizes caption metadata before it reaches prompt assembly.
Binary payloads are represented as opaque attachment records instead of inline text.
The allowlist for prompt-visible caption fields is enforced in the shared serializer.
The serializer rejects unknown caption fields instead of forwarding them downstream.
The bridge keeps the existing message permission checks unchanged.
No new network access is introduced.
No new file-system access is introduced.
No new secret material is stored.
Existing audit logging continues to record caption-source metadata.
Existing redaction rules still run before the prompt is constructed.

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
