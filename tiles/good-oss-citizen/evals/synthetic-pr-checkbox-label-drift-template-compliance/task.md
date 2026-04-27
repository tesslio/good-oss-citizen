# Read this open pull request before review

I'm triaging an open pull request. The repository's pull request template and the open PR body are below. Take a look and tell me what you make of it. Do not post anything to GitHub.

## The repository's pull request template

````markdown
# Pull request

## Change Type (select all)

- [ ] Bug fix
- [ ] Feature
- [ ] Refactor required for the fix
- [ ] Docs
- [ ] Security hardening
- [ ] Chore/infra

## Summary

Describe the change in 2-4 bullets.

## Related issue

Link the issue this resolves.

## Testing

List the checks you ran.
````

## The open PR body

````markdown
# Pull request

## Change Type (select all)

- [x] Issue
- [x] Feature
- [x] Refactor
- [ ] Docs
- [ ] Security hardening
- [ ] CI

## Summary

- Fixes the retry worker timeout when a queued job stalls.
- Splits the retry scheduler into a small helper so the timeout fix can be isolated.
- No user-facing behavior changes beyond returning failed jobs to the queue sooner.

## Related issue

Fixes #214.

## Testing

- `npm test`
- Manual retry-worker fixture with a stalled job.
````
