# Look at this open pull request

I'm triaging an open pull request. The repo's PR template, the open body, and the surrounding context (linked issue + a review thread) are below. Take a look and tell me what you make of it. Do not post anything to GitHub.

Repository: `https://github.com/example/queuekeeper`
Default branch: `trunk`
Template path: `.github/PULL_REQUEST_TEMPLATE.md`

## The repository's pull request template

````markdown
# Pull request

## Summary

Describe the user-visible change in 2-4 bullets.

## Related issue

Link the issue this resolves.

## Root cause

Explain why the bug happened. If this is not a bug fix, write `N/A`.

## Risk and security impact

Describe security-sensitive or user-visible risk. If none, write `None`.

## Testing

List automated and manual checks.

## Human verification

Describe how a human reviewed the change.

## Checklist

- [ ] I added or updated tests.
- [ ] I reviewed the docs impact.
- [ ] I checked user-visible behavior.
````

## The open PR body

````markdown
# Pull request

Fixes #60900.

This updates the retry worker so stuck jobs are returned to the queue instead of remaining in limbo.

Testing: `npm test`

The root cause, risk analysis, human verification, and checklist status are already described in the linked issue and review thread.
````

## Context outside the PR body

The linked issue explains that the worker missed a timeout branch after a scheduler refactor. A review comment says a maintainer manually tested the queue recovery path and found no security impact.
