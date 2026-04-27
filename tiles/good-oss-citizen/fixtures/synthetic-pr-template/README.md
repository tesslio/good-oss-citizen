# Synthetic PR-template fixtures

Concrete inputs for evals that exercise the body / template compliance rubric (`skills/preflight/body-template-compliance-rubric.md`).

- Full template: `templates/pr-template.md`
- Filled body files: `bodies/*.md` — each body's filename describes the mutation it carries (e.g. `remove-one-required-section.md`, `rename-selected-checkbox-bugfix-to-issue.md`)
- Expected result buckets: `expected-results.json` — maps each body to the expected rubric outcome (`Matches well enough` / `Slight deviation` / `Significant deviation`)

## How to reproduce the expectations manually

There is no deterministic semantic evaluator for these examples. To reproduce by hand:

1. Read `../../skills/preflight/body-template-compliance-rubric.md`.
2. Compare each `bodyFile` in `expected-results.json` against `templates/pr-template.md`.
3. Apply the body-local evidence rule: only credit information present in the same body file.
4. Confirm the result bucket matches `expectedResult`.

The body files already contain the mutation described by their filename, so reviewers do not need to mentally apply changes to a baseline body.
