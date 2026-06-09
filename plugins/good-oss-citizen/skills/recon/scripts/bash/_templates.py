"""Template path helpers for github.sh."""

ISSUE_TEMPLATE_DIR = ".github/ISSUE_TEMPLATE/"
ISSUE_TEMPLATE_LEGACY_PATHS = (".github/ISSUE_TEMPLATE.md", "ISSUE_TEMPLATE.md")

# `.github/ISSUE_TEMPLATE/config.yml` is GitHub's issue-template chooser
# config (external links, contact methods) — not a fillable template
# body. Excluded from template enumeration. Comparison is
# case-insensitive because GitHub doesn't enforce case on these paths.
_CONFIG_PATHS = (
    ".github/issue_template/config.yml",
    ".github/issue_template/config.yaml",
)


def issue_template_dir_paths(paths, *, extensions=None):
    """Return paths under .github/ISSUE_TEMPLATE/, excluding chooser config files.

    `extensions` filters by suffix when provided (used by `templates-issue` to
    keep only `.md` / `.yml` / `.yaml`). `repo-scan` passes None so any blob
    in the directory is surfaced as a template artifact (subject to the
    config-file exclusion).
    """
    return sorted(
        p for p in paths
        if p.startswith(ISSUE_TEMPLATE_DIR)
        and p.lower() not in _CONFIG_PATHS
        and (extensions is None or p.endswith(extensions))
    )
