# Recon Report Template

Compile ALL script outputs from the recon skill into this structure. Paste the raw script output under each section heading.

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

If the AI policy is a ban, the report should say so explicitly in section 1 and not hand off to downstream skills.
