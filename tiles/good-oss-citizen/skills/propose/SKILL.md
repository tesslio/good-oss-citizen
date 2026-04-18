---
name: propose
description: Analyzes project contribution guidelines, identifies the right venue (pull request, issue, discussion, RFC/KEP/DEP), checks issue metadata (claims, assignments, labels), searches for prior rejected attempts, and drafts proposals formatted to project templates. Use when the user wants to contribute to an open-source project, fix a bug, submit a PR, improve or refactor code, asks where to submit a change, or needs help choosing between PR/issue/discussion/RFC. Triggers on "fix this issue", "submit a PR", "refactor this", "improve this code", "open a pull request". IMPORTANT — run this AFTER recon and BEFORE writing code to verify the right venue and check for prior attempts.
---

# Propose

Determine the right venue for a proposed change and draft the proposal. This skill assumes recon has been done — if it hasn't, run recon first. Only applies to contributions to external open source projects — skip for internal or personal projects.

## Step 1: Check issue metadata

Before proposing anything, run these checks:

**Read the issue AND its comments:**
```bash
bash .tessl/tiles/tessl-labs/good-oss-citizen/skills/recon/scripts/bash/github.sh issue-comments OWNER/REPO NUMBER
```
Check for:
- Is it assigned to someone? If yes, warn — competing PRs are bad etiquette.
- Has someone commented claiming it ("I'd like to work on this", "I'll take this")? Same problem — warn and suggest alternatives.
- Is it labeled "good first issue"? Check AI_POLICY.md — some projects forbid AI on these.
- Is it labeled internal, blocked, or pending design?

**If the issue is claimed or restricted, immediately list alternatives:**
```bash
bash .tessl/tiles/tessl-labs/good-oss-citizen/skills/recon/scripts/bash/github.sh issues-open OWNER/REPO
```
Present the open, unclaimed issues to the contributor. Note any restrictions (good-first-issue labels, etc.) and include the project's AI disclosure format if one exists.

[Research basis: Finding 11](https://github.com/tesslio/good-oss-citizen/blob/main/RESEARCH.md#finding-11-some-issue-labels-carry-special-restrictions)

## Step 2: Search for prior attempts

Search BOTH closed PRs AND closed issues for prior attempts at the same or similar change. This is critical — many bad AI PRs repeat mistakes that were already rejected.

**Search closed PRs:**
```bash
bash .tessl/tiles/tessl-labs/good-oss-citizen/skills/recon/scripts/bash/github.sh prs-closed OWNER/REPO
```
A related PR is one that touches the same file paths, the same function/class names, references the same issue number, or has a title mentioning the same component. For any related PR, read its comments to get the maintainer's rejection reason:
```bash
bash .tessl/tiles/tessl-labs/good-oss-citizen/skills/recon/scripts/bash/github.sh pr-comments OWNER/REPO NUMBER
```

**Search closed issues:**
```bash
bash .tessl/tiles/tessl-labs/good-oss-citizen/skills/recon/scripts/bash/github.sh issues-closed OWNER/REPO
```
Issues closed as "not planned" are explicit rejections. Check the close comment and labels for the reason — look for phrases like "not part of", "out of scope", "not aligned with", "we've decided against."

If similar work was rejected before, report:
- What was attempted
- Why it was rejected (quote the maintainer)
- Whether the current proposal avoids the same mistake

[Research basis: Finding 2](https://github.com/tesslio/good-oss-citizen/blob/main/RESEARCH.md#finding-2-reading-prior-accepted-and-rejected-work-is-a-legitimate-research-step)

## Step 3: Select the venue

Based on the project's governance docs and recon findings, determine the right venue:

**PR** — appropriate when:
- The change is a straightforward bug fix with an existing issue
- The change is small, well-scoped, and aligns with project direction
- The project's `CONTRIBUTING.md` says PRs are welcome for this type of change

**Issue** — appropriate when:
- No issue exists yet for the problem being solved
- The change is non-trivial and needs maintainer buy-in before code is written
- The contributor wants to signal intent and get feedback on approach

**Discussion** — appropriate when:
- The change is exploratory or the contributor wants to gauge interest
- The project uses GitHub Discussions or a mailing list for pre-work conversation

**RFC / KEP / Change Proposal** — appropriate when:
- The project has a formal proposal process (Rust RFCs, Kubernetes KEPs, Django DEPs, Gitea change proposals)
- The change introduces new functionality, deprecations, or breaking changes
- The project's docs explicitly say substantial changes require this process

If unsure, default to opening an issue or discussion first. A premature PR is worse than a slightly delayed one.

[Research basis: Finding 3](https://github.com/tesslio/good-oss-citizen/blob/main/RESEARCH.md#finding-3-a-good-contributor-knows-when-not-to-open-a-pr-yet)

## Step 4: Draft the proposal

Depending on the selected venue:

### For an issue:
- Use the project's issue template if one exists. Fill every section.
- Reference any prior related issues, PRs, or discussions.
- Describe the problem clearly. Describe the proposed approach. Ask if the approach is welcome before implementing.
- Keep it concise — respect maintainer reading time.

**Example of a well-framed issue:**
> **Problem:** `Config.load()` silently ignores unrecognised keys, making misconfiguration hard to debug.
>
> **Proposed approach:** Emit a warning (not an error) for each unrecognised key, with the key name and source file. This preserves backward compatibility while surfacing mistakes early.
>
> Does this direction sound acceptable before I open a PR?

### For a discussion or mailing list post:
- Frame it as a question or proposal, not a fait accompli.
- Show that you've read existing docs and prior work.
- Be explicit about what feedback you're looking for.

### For an RFC / formal proposal:
- Follow the project's RFC template exactly.
- Reference the design principles and prior art the project values.
- Address alternatives considered.

### For a PR (if that's the right venue):
- Hand off to the preflight skill when the code is ready.

### When redirecting away from an issue (restriction, claim, or rejection):
You are NOT done when you tell the contributor they can't work on an issue. Redirecting IS the job — you must help them find what they CAN do. This is mandatory, not a nice-to-have.

**Step A — List every open issue in the repo:**
```bash
bash .tessl/tiles/tessl-labs/good-oss-citizen/skills/recon/scripts/bash/github.sh issues-open OWNER/REPO
```
Present each open issue with its number, title, and any restrictions (assigned? good-first-issue label?).

**Step B — For each viable alternative, include the AI disclosure format:**
If AI_POLICY.md defines a disclosure template, copy-paste it verbatim so the contributor has it ready. Example: "For your PR, you'll need this section:" followed by the exact template from the policy file.

**Step C — If the restriction is "no AI on this issue" (e.g., good-first-issue):**
Explain WHY: good-first-issue labels are reserved for newcomers to learn the codebase hands-on — AI assistance defeats their purpose. Note the consequence from AI_POLICY.md if stated (e.g., "PRs will be closed"). Then help the contributor succeed WITHOUT AI on the restricted issue:
- Quote any approach hints from the issue description (e.g., "see the pattern in env.go")
- Point to specific code files or functions the issue references
- Summarize relevant conventions from the recon report (test framework, commit format, etc.)
- State the recommended learning path explicitly as a progression: "The project recommends: complete a good-first-issue without AI to build codebase familiarity, then use AI assistance on more complex issues where maintainers welcome it." If AI_POLICY.md defines a specific path, quote it. Do not just imply the path through option structure — articulate it as the project's recommended progression.

[Research basis: Finding 4](https://github.com/tesslio/good-oss-citizen/blob/main/RESEARCH.md#finding-4-accepted-contributions-are-usually-scoped-explicit-and-test-backed)

## Step 5: Surface trust-building context

Remind the contributor that trust is socially accumulated in OSS. If they are new to this project, their first contribution has to work harder to earn trust. Suggest:
- Starting with a smaller contribution if the proposed change is large
- Engaging in existing issues or discussions first to become a known presence
- Being transparent about AI assistance from the start — for example: *"I used an AI assistant to help draft this proposal and will review all suggestions carefully before submitting."*

[Research basis: Finding 7](https://github.com/tesslio/good-oss-citizen/blob/main/RESEARCH.md#finding-7-trust-starts-before-the-pull-request)
