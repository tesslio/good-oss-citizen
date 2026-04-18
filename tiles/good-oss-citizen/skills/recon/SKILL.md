---
name: recon
description: Analyze an open source project's contribution norms, AI policy, conventions, and recent PR history before writing any code. Use when the user wants to contribute to an open source or GitHub project, fix a bug, submit a pull request, open a PR, make a contribution, or asks about contribution guidelines. Triggers on phrases like "fix this bug", "submit a PR", "contribute a fix", "open a pull request", "help me contribute", "how do I contribute", "what are the rules for this OSS project". IMPORTANT — run this BEFORE writing any code for an open source project.
---

# Recon

Analyze an open source project to understand its contribution norms before any code is written. This skill produces a report for the contributor — not a PR, not code, just intelligence.

Helper script path: `bash .tessl/tiles/tessl-labs/good-oss-citizen/skills/recon/scripts/bash/github.sh`

## Step 0: Verify this is an OSS contribution

Confirm the task involves contributing to an external open source project (GitHub URL, "submit a PR", "contribute a fix", etc.). If internal or personal project — skip this skill entirely.

## Step 1: Run repo-scan

```bash
bash .tessl/tiles/tessl-labs/good-oss-citizen/skills/recon/scripts/bash/github.sh repo-scan OWNER/REPO
```
Parse output. Note every FOUND and NOT FOUND file. Proceed to Step 2.

## Step 2: Can I contribute? (hard stops)

```bash
bash .tessl/tiles/tessl-labs/good-oss-citizen/skills/recon/scripts/bash/github.sh ai-policy OWNER/REPO
```
The script returns the full text of AI_POLICY.md, CODE_OF_CONDUCT.md, and CONTRIBUTING.md (if they exist). Read them and determine the project's AI stance. Look for explicit negatives alongside "AI": "do not", "cannot", "banned", "prohibited", "not allowed", "not accepted." Check for hard-stop consequences: "PRs will be closed", "contributions rejected", "account suspended." If you find these, that's a ban. Look for disclosure language: "must disclose", "required to disclose", "include what tool." Check for conditional restrictions: "AI not allowed on good-first-issue", "AI only with full human review." Absence of any AI mention means no policy — NOT a ban. Then act:
- If AI contributions are **banned** (any phrasing): **STOP.** Tell the contributor: the project bans AI contributions, explain the consequences, and suggest they can still contribute WITHOUT AI (provide project conventions from later steps if helpful).
- If AI **disclosure is required** (any phrasing): continue, note the requirement.
- If there are **conditions or restrictions** (e.g., AI banned on good-first-issue labels, AI allowed only with full human review): continue, note them.
- If **no AI policy** exists: continue, recommend voluntary disclosure. Include this in your recon report: "This project has no AI policy. Voluntary disclosure is recommended — it builds trust and protects you if the project adds a policy later."

## Step 3: Should I work on THIS issue? (issue checks)

Run ALL three commands — these are not optional:
```bash
bash .tessl/tiles/tessl-labs/good-oss-citizen/skills/recon/scripts/bash/github.sh issue OWNER/REPO ISSUE_NUMBER
```
```bash
bash .tessl/tiles/tessl-labs/good-oss-citizen/skills/recon/scripts/bash/github.sh issue-comments OWNER/REPO ISSUE_NUMBER
```
```bash
bash .tessl/tiles/tessl-labs/good-oss-citizen/skills/recon/scripts/bash/github.sh related-prs OWNER/REPO ISSUE_NUMBER
```
After running `issue-comments`, answer this question before anything else: **Is this issue claimed by another contributor?** A claim is any comment where someone expresses intent to work on the issue: "I'd like to work on this", "I'll take this", "claiming this", "I'm working on this", "I can take this", "let me handle this", "I've started a branch for this", "assigned to me", mentioning having a PR ready, or any equivalent in any language.

If ANYONE has claimed it: **STOP — do NOT proceed to later steps or write code.** Tell the contributor who claimed it (username and date), warn that competing PRs are bad etiquette and will likely be rejected, then run `issues-open` to list alternatives and run `disclosure-format OWNER/REPO` so you can include the exact AI disclosure template for those alternatives. If the project has no AI policy, include the voluntary disclosure template instead. This is a hard stop.

If NOT claimed, continue with remaining checks:
- Cross-reference the issue output (labels, assignment) against any restrictions found in Step 2. If the AI policy restricts AI usage on issues with specific labels (e.g., "good first issue") and THIS issue has that label: **STOP.** Tell the contributor about the restriction, explain why it exists (these issues are learning opportunities for newcomers — AI defeats their purpose), and list alternative issues they CAN work on with AI.
- If related-prs returns prior rejected attempts: tell the contributor WHAT was tried, WHO rejected it, and WHY — quote the maintainer. The contributor must adapt their approach to avoid the same mistakes.

## Step 4: Get disclosure format

```bash
bash .tessl/tiles/tessl-labs/good-oss-citizen/skills/recon/scripts/bash/github.sh disclosure-format OWNER/REPO
```
Save the exact template for the PR description. If no policy, recommend voluntary disclosure.

## Step 5: Extract conventions and requirements

Run ALL commands:
```bash
bash .tessl/tiles/tessl-labs/good-oss-citizen/skills/recon/scripts/bash/github.sh conventions-config OWNER/REPO
```
```bash
bash .tessl/tiles/tessl-labs/good-oss-citizen/skills/recon/scripts/bash/github.sh contributing-requirements OWNER/REPO
```
```bash
bash .tessl/tiles/tessl-labs/good-oss-citizen/skills/recon/scripts/bash/github.sh commit-conventions OWNER/REPO
```
```bash
bash .tessl/tiles/tessl-labs/good-oss-citizen/skills/recon/scripts/bash/github.sh branch-conventions OWNER/REPO
```
```bash
bash .tessl/tiles/tessl-labs/good-oss-citizen/skills/recon/scripts/bash/github.sh pr-stats OWNER/REPO
```
```bash
bash .tessl/tiles/tessl-labs/good-oss-citizen/skills/recon/scripts/bash/github.sh codeowners OWNER/REPO
```
```bash
bash .tessl/tiles/tessl-labs/good-oss-citizen/skills/recon/scripts/bash/github.sh legal OWNER/REPO
```
The contributing-requirements script returns the full CONTRIBUTING.md text. Read it and extract requirements. Look for imperative language: "you must", "required", "must include", "always", "do not." These indicate hard requirements. Softer language ("we recommend", "we appreciate", "consider") indicates preferences, not requirements. Then note action items:
- If DCO/sign-off is required (any phrasing): tell the contributor "You must use `git commit -s` to add Signed-off-by. The agent cannot sign for you — this is a legal attestation."
- If changelog updates are required (any phrasing): you must update CHANGELOG.md with the change.
- If tests are required (any phrasing): you must include regression tests.
- If conventions-config shows .editorconfig or .pre-commit-config settings: you must follow them exactly (indent_size, line_length, hooks).
- Use commit-conventions and branch-conventions outputs as the exact format to follow. Do not guess. Create the actual branch and commit with the exact format — do not just describe the convention.
- If CONTRIBUTING.md mentions running linters (e.g., `make lint`, `npm run lint`), add this to the action items. Both tests AND linters must pass before submission.

## Step 6: Read files that need human interpretation

Read these FOUND files using the `file` command:
```bash
bash .tessl/tiles/tessl-labs/good-oss-citizen/skills/recon/scripts/bash/github.sh file OWNER/REPO <path>
```
Specifically read and act on:
- Agent instruction files (AGENTS.md, .cursorrules): these carry the SAME authority as CONTRIBUTING.md. Extract every instruction and add to your requirements list.
- conftest.py or test helpers: note which fixtures exist — you MUST use them in your tests, not reinvent them.
- DEVELOPMENT.md: extract test naming conventions, setup requirements — follow them exactly.
- CHANGELOG.md: note the format — you will need to add an entry matching it.
- PR template: note every section and checkbox — you will need to fill them all.

## Step 7: List open issues (if redirecting)

If the contributor needs alternatives (claimed issue, restricted issue, or rejected direction):
```bash
bash .tessl/tiles/tessl-labs/good-oss-citizen/skills/recon/scripts/bash/github.sh issues-open OWNER/REPO
```
Present each open issue with its number, title, labels, and assignment status.

## Step 8: Produce the recon report

Compile ALL script outputs into a structured report:

```
## Recon Report: <project-name>

### 1. AI Policy Stance
<paste ai-policy output>

### 2. Issue Status
<paste issue + issue-comments output>
<paste related-prs output>

### 3. Disclosure Format
<paste disclosure-format output>

### 4. Legal Requirements
<paste legal output>

### 5. Contribution Process
<paste contributing-requirements output>

### 6. Style and Conventions
<paste conventions-config output>
<paste commit-conventions output>
<paste branch-conventions output>

### 7. PR Norms
<paste pr-stats output>
<from PR template file output>

### 8. Red Flags
<from issue-comments, related-prs, ai-policy outputs>

### 9. Who Reviews What
<paste codeowners output>

### 10. Action Items for Contributor
<list every action the contributor must take: DCO sign-off, changelog update, disclosure section, specific test fixtures to use, etc.>
```

If the AI policy is a ban, the report should say so and not proceed to other skills.
