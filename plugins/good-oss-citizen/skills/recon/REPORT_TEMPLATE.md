# Recon Report Template

The recon helper commands now emit JSON envelopes (see `skills/recon/SKILL.md` for the contract). For each section below, summarize the relevant fields from the command's `data` payload — do **not** paste the raw envelope JSON.

```
## Recon Report: <project-name>

### 1. AI Policy Stance
<from `ai-policy.data.files`: which files were found, and the stance you derived (banned / disclosure required / conditional / no policy)>

### 2. Issue Status
<from `issue.data` (number, title, state, labels, assignee) + `issue-comments.data.comments`>
<from `related-prs.data.prs`: each prior PR's number, title, merged state, and rejection comments if any>

### 3. Disclosure Format
<from `disclosure-format.data`: format (code_block / prose / none) and the template, if any>

### 4. Legal Requirements
<from `legal.data`: dco_file, signed_off_count/total, license, ci_workflows>

### 5. Contribution Process
<from `contributing-requirements.data.content` — extracted requirements (DCO, changelog, tests, issue-first, etc.)>

### 6. Style and Conventions
<from `conventions-config.data` — editorconfig / pre_commit_config / pyproject_tool when present>
<from `commit-conventions.data` — format, signed_off_required, examples>
<from `branch-conventions.data` — dominant, issue_numbers_in_branch, examples>

### 7. PR Norms
<from `pr-stats.data` — sample_size, additions/deletions/files medians, guideline.max_additions / max_files>
<from PR template file output (templates-pr.data.templates)>

### 8. Red Flags
<synthesized from issue-comments, related-prs, ai-policy>

### 9. Who Reviews What
<from `codeowners.data.rules` — each rule's path and owners>

### 10. Action Items for Contributor
<list every action the contributor must take: DCO sign-off, changelog update, disclosure section, specific test fixtures to use, etc.>
```

If the AI policy is a ban, the report should say so explicitly in section 1 and not hand off to downstream skills.
