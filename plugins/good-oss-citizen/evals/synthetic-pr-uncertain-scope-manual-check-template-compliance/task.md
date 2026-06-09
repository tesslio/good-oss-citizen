# Check a pull request body with mixed scope signals

I'm triaging an open pull request. The repository's pull request template and the open PR body are below. Tell me whether the body follows the template and whether I should ask the contributor to revise it. Do not post anything to GitHub.

## The repository's pull request template

````markdown
# Pull request

## Change Type (select all)

- [ ] Bug fix
- [ ] Feature
- [ ] Refactor
- [ ] Docs
- [ ] Chore

## Summary

Describe the change in 2-4 bullets.

## User-visible changes

Describe any behavior, UI, API, or configuration changes users should know about. If none, write `None`.

## Testing

List the checks you ran.

## Human verification

Describe how a human reviewed the change.
````

## The open PR body

````markdown
# Pull request

## Change Type (select all)

- [x] Bug fix
- [x] Feature
- [ ] Refactor
- [ ] Docs
- [ ] Chore

## Summary

- Fixes intermittent autosave failures when an editor session token expires.
- Adds a `saveDiagnostics` field to the internal debug payload so support can trace failed autosaves.
- Keeps the editor UI and save flow unchanged.

## User-visible changes

None.

## Testing

- `npm test`
- Manual expired-token autosave fixture.

## Human verification

Reviewed the diff, test output, and generated PR body before submission.
````
