"""JSON envelope + GitHub fetch helpers for github.sh.

Every command in github.sh prints exactly one envelope object on stdout:

    {
      "command":  "<name>",
      "ok":       <bool>,
      "data":     <object|null>,
      "warnings": [<str>, ...],
      "errors":   [<str>, ...]
    }

`emit` is the success path; `fail` writes an envelope with ok=false and
exits non-zero so bash callers can detect failure.

`fetch` / `fetch_json` are the shared GitHub API client — gh CLI first,
curl fallback. Defining them here keeps every command's behavior
identical (auth, timeout, error handling) without per-command drift.
"""

import json
import subprocess
import sys

API = "https://api.github.com"
TIMEOUT = 15


def emit(command, data, *, warnings=None, errors=None, ok=True):
    payload = {
        "command": command,
        "ok": ok,
        "data": data,
        "warnings": list(warnings or []),
        "errors": list(errors or []),
    }
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def fail(command, message):
    # script-delegation.md requires both: non-zero exit AND a stderr
    # diagnostic. Stdout stays reserved for the JSON envelope so machine
    # consumers can parse cleanly; stderr carries the human-readable
    # message for log scrapers and CI.
    sys.stderr.write(f"github.sh {command}: {message}\n")
    emit(command, None, errors=[message], ok=False)
    sys.exit(1)


def fetch(endpoint):
    """Fetch a GitHub API response body. Returns "" on failure.

    Tries `gh api` first (so authenticated calls work in CI), then falls
    back to curl for unauthenticated public access.

    All failure modes — 404, 403/rate-limit, auth, network, timeout —
    collapse to "" by design. Many commands here treat "absent file" as
    a normal outcome (e.g. an OSS repo without `AI_POLICY.md`), so a
    naive raise-on-error wrapper would misreport that case as a tile
    bug. The tradeoff is that hard failures look the same as a clean
    404 to the caller.

    Mitigation in callers: when the absence of an optional resource
    would meaningfully change the recon report (e.g. PR rejection
    comments hiding a fetch failure), the calling command should attach
    a `warnings[]` entry rather than silently emit a partial answer.
    """
    attempts = (
        ["gh", "api", endpoint],
        ["curl", "-sf", "-H", "Accept: application/vnd.github+json",
         f"{API}{endpoint}"],
    )
    for cmd in attempts:
        try:
            r = subprocess.run(
                cmd, capture_output=True, text=True, timeout=TIMEOUT
            )
        except (FileNotFoundError, subprocess.TimeoutExpired):
            continue
        if r.returncode == 0 and r.stdout:
            return r.stdout
    return ""


def fetch_json(endpoint):
    """Fetch + JSON-decode. Returns the parsed value, or None on failure."""
    body = fetch(endpoint)
    if not body.strip():
        return None
    try:
        return json.loads(body)
    except json.JSONDecodeError:
        return None
