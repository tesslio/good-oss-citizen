# Synthetic filled PR body

## Change type (required)
Select all that apply:
- [x] Bug fix
- [x] Security hardening
- [ ] Documentation

## Summary (required)
- Fixes token handling in the message bridge.
- Keeps binary payloads out of prompt-visible text.

## Security Impact (required)
Reduces prompt-injection and token-inflation exposure from binary captions.

## Compatibility / Migration (required)
- Backward compatible? (Yes/No) Yes
- Config/env changes? (Yes/No) No
- Migration needed? (Yes/No) No
- If yes, exact upgrade steps: N/A

## Repro / Verification (required)
The bridge treated all caption-like payloads as prompt text. Verified with unit tests and a manual binary-caption fixture.

## User-visible changes (required)
None.

## Environment (required)
- OS: Linux
- Node: 22

## Human verification (required)
Reviewed the diff, tests, and generated PR body before submission.

New permissions/capabilities? (Yes/No) No
