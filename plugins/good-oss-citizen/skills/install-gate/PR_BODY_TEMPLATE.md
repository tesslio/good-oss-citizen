# Install-Gate PR Body Template

Reference for Step 7 of the `install-gate` skill. Pulled out of SKILL.md so the main flow stays scannable.

## Required content

The PR body the skill opens must include the following content blocks, in this order.

### 1. What the gate does, and what it does NOT do

Explain that the workflow runs on every pull request and fails it unless the description carries a contribution declaration — either an **AI Disclosure** section or an explicit **no-AI** statement — and posts a sticky comment when it's missing.

State the honest framing plainly: the gate enforces an **outcome** (AI use is disclosed, or declared absent) on the PR side, where it cannot be bypassed. It does **not**, and cannot, prove that any particular tool ran — a careful human who writes a disclosure by hand passes by design. `tessl.json` (added by this PR) is what actually drives tessl-aware agents to install and use good-oss-citizen; the gate is the enforcement net for everyone else.

### 2. What this PR installs

List the scaffolded paths from Step 4's JSON summary:

- `.github/workflows/contribution-gate.yml` — the PR-side gate (`pull_request_target`, so it also works on fork PRs).
- `.github/scripts/check_contribution_declaration.py` — the vendored, stdlib-only detector the workflow runs.
- The PR template — note whether it was **created** (`.github/PULL_REQUEST_TEMPLATE.md`) or **left in place** (existing template; see the warnings block).
- `tessl.json` — note whether the `tessl-labs/good-oss-citizen` dependency was **created**, **added**, or **already present** (with the version).

### 3. Make the check required before this is real enforcement

The gate runs on every PR as soon as this merges, but a passing/failing check does not block a merge until it is marked **required**. Tell the maintainer to add the status check named **`Contribution declaration`** (job name, under the *good-oss-citizen contribution gate* workflow) to the branch-protection required checks for the default branch: `Settings → Branches → Branch protection rules`. Note that no repository secrets are needed — the workflow uses the built-in `GITHUB_TOKEN` with `pull-requests: write`.

### 4. (Conditional) "Action required before merge" — only if Step 1 or Step 4 emitted warnings

If preflight or scaffold returned a non-empty `warnings` array, add an `## Action required before merge` section reproducing each warning's text verbatim. The most common one: the repo already had a PR template, so the gate did not modify it and the maintainer must add a declaration block (a no-AI checkbox and/or an AI Disclosure section) to that template by hand — otherwise every PR using it fails the gate.

If there were no warnings, omit the section entirely.

### 5. AI Disclosure

This PR is opened by an agent running the `install-gate` skill, so it must carry its own AI Disclosure section — modeling exactly what the gate asks of every future contributor. Use a short prose disclosure: that the gate files were scaffolded by good-oss-citizen's `install-gate` skill and the maintainer reviewed them before merging. Do not fence it.
