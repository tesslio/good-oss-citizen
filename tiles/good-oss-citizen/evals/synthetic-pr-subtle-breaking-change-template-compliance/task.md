# Check a synthetic PR body for subtle template-compliance issues

I want a final-verification pass on a draft PR body before I open the pull request. Compare these two local files and tell me whether the body matches the template, partially matches, or significantly deviates — and surface anything in the body that a reviewer would want to look at by hand.

- Template: `tiles/good-oss-citizen/fixtures/synthetic-pr-template/templates/pr-template.md`
- PR body: `tiles/good-oss-citizen/fixtures/synthetic-pr-template/bodies/introduce-breaking-change-contradiction.md`

Do not post anything to GitHub. Return the structured compliance result and, if useful, a concise suggested comment or an optional manual-check snippet.
