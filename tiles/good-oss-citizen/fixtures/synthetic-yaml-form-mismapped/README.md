# Synthetic fixture: YAML form template + body that uses freeform markdown headings

A repository ships a YAML issue form template (`.github/ISSUE_TEMPLATE/bug.yml`) with declared fields by `id` and `label` (`version`, `what-happened`, `expected`, `repro`, `logs`). A contributor opens an issue but writes a freeform markdown body with their own headings (`## Description`, `## Environment`, `## Reproduction`, `## Expected`, `## Logs / extra context`) instead of mapping their answers into the form's declared fields.

The body / template compliance rubric covers this case in two distinct ways:

- **Content equivalence:** the rubric's "Content-equivalent answers" rule says a field counts as present when the author clearly provides the substance, even when they reformat or reword. The freeform body in this fixture answers the substance of every required form field — the form's required fields are `version`, `what-happened`, `expected`, `repro`; the body has Library version (`2.4.1`), Description (the unexpected behavior), Reproduction steps, and Expected behavior.
- **YAML-form vocabulary:** the rubric's "YAML issue form rules" + "Suggested fix/comment rules" say to map fields by `id` / `label`, never call the template a `form` in suggested comments, and (in the rubric's broader vocabulary rule) "Always use the word `template`, never `form`" when describing the artefact to the contributor.

This fixture exists to test triage-time application of those two rules — particularly the failure mode where a baseline agent grades the freeform body harshly because its headings don't match the YAML field labels verbatim.

- `templates/bug.yml` — YAML form with required fields `version`, `what-happened`, `expected`, `repro` and an optional `logs` field.
- `bodies/freeform-headings.md` — body with freeform headings whose substance covers every required field.
