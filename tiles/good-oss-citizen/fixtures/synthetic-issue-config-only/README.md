# Synthetic fixture: issue-template chooser config without any actual templates

A repository's `.github/ISSUE_TEMPLATE/` directory may contain only `config.yml`, which configures GitHub's issue-template chooser (blank-issue toggle, contact links to security disclosure / discussions / chat) without supplying any fillable issue templates. The body / template compliance rubric explicitly handles this:

> Discard `.github/ISSUE_TEMPLATE/config.yml` and `.github/ISSUE_TEMPLATE/config.yaml` before counting or selecting issue templates. … If only chooser config files remain, treat the repository as having no issue body template.

This fixture set lets evals exercise that branch deterministically without needing a public repo configured this way.

- `templates/config.yml` — a chooser-config-only file (blank issues disabled, two contact links). Mirrors the shape GitHub's docs prescribe for `.github/ISSUE_TEMPLATE/config.yml`.
- `bodies/incomplete-bug-report.md` — an issue body that's reasonable but has no specific template to compare against.

Used by the `triage-issue-template-config-only` eval.
