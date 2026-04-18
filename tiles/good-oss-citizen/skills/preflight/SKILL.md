---
name: preflight
description: "Runs a structured 9-check pre-submission checklist against an open-source contribution before the contributor opens a pull request. Use when the user has written code for an open-source project and needs to prepare a PR, submit a contribution, or verify readiness. Triggers on \"submit a PR\", \"open a pull request\", \"prepare the contribution\", \"ready to merge\", \"check my pull request\". IMPORTANT — run this AFTER code is written but BEFORE submission. Checks: AI policy compliance and disclosure (including voluntary disclosure when no policy exists), diff size and focus, PR template, code style, commit conventions, tests, legal requirements (DCO/CLA), agent artifacts, changelog, and human ownership verification."
---

# Preflight

Run a pre-submission checklist before the contributor hits "Create Pull Request." Only applies to contributions to external open source projects — skip for internal or personal projects. This skill assumes recon has been done and the venue decision has been made. If a PR is not the right venue, this skill should not be running — go back to propose.

## Check 1: AI disclosure in PR description (MANDATORY)

Every PR description MUST contain an AI disclosure section. Check for it first — this is the most commonly missed item.

- **Project requires AI disclosure:** verify it matches the exact format from AI_POLICY.md.
- **Project has no AI policy:** add voluntary disclosure: "**AI Disclosure:** Code drafted with [tool name], reviewed and modified by the contributor. Tests [written manually / reviewed by contributor]. All code was reviewed and tested by the human contributor before submission."
- **Project bans AI contributions:** stop. Do not proceed.

Disclosure should be specific: which tool, what it was used for, what was human-written vs. AI-assisted.

| Quality | Example |
|---------|---------|
| Bad | "I used AI to help write this." |
| Good | "Code drafted with Claude Code, reviewed and modified by me, tests written manually." |

**Self-check:** Can you see an "AI Disclosure" or equivalent section in the PR description? If not, add one now.

[Research basis: Finding 5](https://github.com/tesslio/good-oss-citizen/blob/main/RESEARCH.md#finding-5-ai-policy-is-local-and-it-varies-widely)

## Check 2: Diff size and focus

Compare the PR's diff against typical PR size from recon findings:
- Flag if the diff exceeds 2x the project's typical PR size from recon findings (or 500 lines if no baseline is available).
- Flag if the PR touches files unrelated to the stated issue.
- Flag if the PR bundles multiple unrelated changes.
- If oversized, help the contributor decompose into smaller PRs.

[Research basis: Finding 4](https://github.com/tesslio/good-oss-citizen/blob/main/RESEARCH.md#finding-4-accepted-contributions-are-usually-scoped-explicit-and-test-backed), [Finding 16](https://github.com/tesslio/good-oss-citizen/blob/main/RESEARCH.md#finding-16-the-asymmetric-effort-problem-is-the-root-economic-failure)

## Check 3: PR template compliance

If the project has a PR template:
- Verify every section is filled. Do not delete template sections.
- Verify the linked issue reference is present.
- Verify any required checkboxes (AI disclosure, testing confirmation, CLA) are addressed.

If no template exists, verify the PR description at minimum contains:
- What changed and why
- Reference to the issue being addressed
- How to test the change

[Research basis: Finding 1](https://github.com/tesslio/good-oss-citizen/blob/main/RESEARCH.md#finding-1-repo-local-process-is-the-real-contract)

## Check 4: Style and convention compliance

Verify the contribution matches project conventions discovered during recon:
- Code formatting matches `.editorconfig`, linter, and formatter configs.
- Commit messages match the project's convention (Conventional Commits, imperative mood, signed-off, etc.). Create an actual commit with the correct format — e.g., `fix(queue): raise QueueFullError when queue is at capacity`. Do not just describe the format in the PR checklist; produce the artifact.
- Branch naming matches the project's convention. Create the branch with the correct name — e.g., `fix/2-queue-full-error`. Do not just claim compliance in the checklist.
- Import ordering, naming conventions, and comment style match existing code.
- If no config files exist, check 3-5 existing files in the same directory for: indentation (spaces vs tabs, 2 vs 4), line length, comment style, naming conventions (camelCase vs snake_case). Match the majority pattern.

[Research basis: Finding 9](https://github.com/tesslio/good-oss-citizen/blob/main/RESEARCH.md#finding-9-code-convention-files-are-part-of-the-contract)

## Check 5: Tests and CI

- Verify tests are included if the project expects them.
- Verify tests match the project's testing patterns (framework, file naming, assertion style, fixtures).
- Run ALL of the project's local checks — both tests AND linters. If CONTRIBUTING.md says `make test` and `make lint`, run both. If it says `npm test` and `npm run lint`, run both. Do not run only tests and skip linting. Do not rely on CI to catch problems — that shifts the burden to maintainers.

[Research basis: Finding 4](https://github.com/tesslio/good-oss-citizen/blob/main/RESEARCH.md#finding-4-accepted-contributions-are-usually-scoped-explicit-and-test-backed)

## Check 5.5: Changelog and metadata

- If `CHANGELOG.md` exists and CONTRIBUTING.md mentions updating it, verify the contributor has added an entry under `[Unreleased]` for the change.
- Check for other metadata requirements: `AUTHORS` file updates, version bumps, etc.
- This is one of the most commonly missed steps — agents fix the code but forget the housekeeping.

## Check 6: Legal requirements (DCO/CLA)

- If DCO sign-off is required: include an explicit instruction in the PR description — "**DCO Notice:** All commits must include `Signed-off-by:` via `git commit -s`. This is a legal attestation the contributor must make personally — the AI agent cannot sign on your behalf." Do NOT just check a box in the PR template.
- If CLA is required, remind the contributor they will need to sign it.
- If the license has compatibility concerns with AI tool terms, flag them.

[Research basis: Finding 10](https://github.com/tesslio/good-oss-citizen/blob/main/RESEARCH.md#finding-10-dcocla-requirements-are-a-hard-boundary-the-agent-must-not-cross)

## Check 7: Agent artifact cleanup

Verify the contribution does not include:
- `.claude/`, `.cursor/`, `.aider/`, or other agent tool directories
- AI-generated comments that describe intent rather than reality (e.g., "This function efficiently handles..." when it doesn't)
- Characteristic AI verbosity in code comments, commit messages, or PR description
- Hallucinated package names or dependencies that don't exist

To detect leaked agent directories, run:
```sh
find . -type d \( -name '.claude' -o -name '.cursor' -o -name '.aider' -o -name '.continue' \) ! -path './.git/*'
```
Any output from this command is a blocker — remove those directories before submission.

[Research basis: Finding 13](https://github.com/tesslio/good-oss-citizen/blob/main/RESEARCH.md#finding-13-agent-metafiles-must-never-leak-into-contributions), [Finding 15](https://github.com/tesslio/good-oss-citizen/blob/main/RESEARCH.md#finding-15-security-aware-code-generation-is-a-specific-responsibility)

## Check 8: Slop detector patterns

Verify the contribution does not exhibit patterns flagged by automated slop detectors:
- Multiple PRs opened in rapid succession across different repos
- Large unfocused diffs with AI formatting tells (excessive blank lines, verbose comments, placeholder TODOs, unused imports, code that doesn't match surrounding style)
- PR submitted by a contributor with no prior engagement in the project
- Fire-and-forget pattern (warn the contributor they MUST stay engaged through review)

[Research basis: Finding 12](https://github.com/tesslio/good-oss-citizen/blob/main/RESEARCH.md#finding-12-slop-detection-tools-exist-and-the-agent-should-know-how-to-not-trigger-them)

## Check 9: Human ownership verification

Before submitting, confirm with the contributor:
- Can you explain every change in this PR without AI assistance?
- Can you respond to reviewer questions about design decisions personally?
- Are you committed to iterating on review feedback until the PR converges or is withdrawn?

If the answer to any of these is no, the PR is not ready.

[Research basis: Finding 6](https://github.com/tesslio/good-oss-citizen/blob/main/RESEARCH.md#finding-6-blanket-rejection-of-ai-assisted-work-is-too-crude-but-ai-wrote-it-is-not-enough-either), [Finding 7](https://github.com/tesslio/good-oss-citizen/blob/main/RESEARCH.md#finding-7-trust-starts-before-the-pull-request)

## Produce the preflight report

Summarize as a checklist with pass/fail/warning for each check. For any failures, explain what needs to change before submission. For warnings, explain the risk and let the contributor decide.

## Required output artifacts

Before you are done, verify these artifacts exist:
- **PR description draft** (e.g., assistant output or a local-only `pr_description.md`) — with AI disclosure section, issue reference, and all PR template sections filled. This is a required deliverable, not optional. If you place it in a file, keep it out of the PR diff: do **not** add, commit, or push that file to the repository.
- **Git commit** with the correct message format (e.g., Conventional Commits if required). The commit must exist as an actual artifact, not just a description in a checklist.
- **Git branch** with the correct naming convention. The branch must exist, not just be claimed in a checklist.

Do not submit the PR. That is the contributor's action.
