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
import os
import subprocess
import sys
import traceback

API = "https://api.github.com"
TIMEOUT = 15


def _install_excepthook():
    """Make every command emit a valid envelope even on unhandled exceptions.

    Without this hook a `KeyError` on an unexpected GitHub API shape (or
    any other unhandled exception inside a python heredoc in github.sh)
    would print a Python traceback to stderr and *no* envelope to stdout
    — breaking the contract that every invocation prints exactly one
    envelope. The hook intercepts the dying interpreter, writes a
    failure envelope, and exits non-zero so consumers can still parse.
    """
    def hook(exc_type, exc, tb):
        if exc_type is SystemExit:
            sys.__excepthook__(exc_type, exc, tb)
            return
        cmd = os.environ.get("COMMAND", "unknown")
        details = "".join(traceback.format_exception_only(exc_type, exc)).strip()
        sys.stderr.write(f"github.sh {cmd}: unhandled exception: {details}\n")
        sys.stderr.write("".join(traceback.format_exception(exc_type, exc, tb)))
        emit(cmd, None,
             errors=[f"unhandled exception: {details}"], ok=False)
        sys.exit(1)
    sys.excepthook = hook


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


def _curl_auth_config():
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if not token:
        return None
    # curl parses a double-quoted config value with backslash escapes and ends
    # it at the first unescaped quote, so a token containing " or \\ would
    # silently mangle the header (dropping to unauthenticated limits with no
    # diagnostic) and a newline could inject further curl directives. Current
    # GitHub tokens are alphanumeric, so this is defensive rather than a live
    # bug, but the escaping costs nothing.
    # curl's config parser is line-oriented, so a newline in the value starts a
    # new directive: a token containing "\nproxy = http://attacker" would
    # silently route every request through that host. Escape the line breaks as
    # well as the quoting characters.
    escaped = (
        token.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\r", "\\r")
        .replace("\n", "\\n")
    )
    return f'header = "Authorization: Bearer {escaped}"\n'


def fetch(endpoint):
    """Fetch a GitHub API response body. Returns "" on failure.

    Tries `gh api` first (so authenticated calls work in CI), then falls
    back to curl for unauthenticated public access.

    All failure modes — 404, 403/rate-limit, auth, network, timeout —
    collapse to "" by design. Many commands here treat "absent file" as
    a normal outcome (e.g. an OSS repo without `AI_POLICY.md`), so a
    naive raise-on-error wrapper would misreport that case as a plugin
    bug. The tradeoff is that hard failures look the same as a clean
    404 to the caller.

    Mitigation in callers: when the absence of an optional resource
    would meaningfully change the recon report (e.g. PR rejection
    comments hiding a fetch failure), the calling command should attach
    a `warnings[]` entry rather than silently emit a partial answer.
    """
    curl_cmd = ["curl", "-sf", "-H", "Accept: application/vnd.github+json"]
    curl_config = _curl_auth_config()
    if curl_config:
        # Curl gets the same authenticated 5000-req/hr limit as gh when a
        # token is in the env. Without this, environments without gh fall
        # back to the 60-req/hr unauthenticated public limit and the
        # command sweep smoke test would race the limit. Pass the secret
        # through stdin config so it is not visible in argv.
        curl_cmd += ["--config", "-"]
    curl_cmd += [f"{API}{endpoint}"]

    attempts = ((["gh", "api", endpoint], None), (curl_cmd, curl_config))
    for cmd, stdin in attempts:
        try:
            r = subprocess.run(
                cmd, capture_output=True, input=stdin, text=True, timeout=TIMEOUT
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


def _parse_response_with_headers(stdout):
    header_text, separator, body = stdout.replace("\r\n", "\n").partition("\n\n")
    if not separator:
        return None, None
    status = None
    for line in header_text.split("\n"):
        if line.startswith("HTTP/"):
            parts = line.split()
            if len(parts) >= 2:
                try:
                    status = int(parts[1])
                except ValueError:
                    # A proxy can inject an odd status line; that should not
                    # discard a status already parsed from the real response.
                    continue
    if status is None:
        return None, None
    if not body.strip():
        return None, status
    try:
        return json.loads(body), status
    except json.JSONDecodeError:
        return None, status


def fetch_json_with_status(endpoint):
    """Fetch + JSON-decode with HTTP status. Returns (data, status)."""
    try:
        gh_result = subprocess.run(
            ["gh", "api", "-i", endpoint],
            capture_output=True,
            text=True,
            timeout=TIMEOUT,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        gh_result = None
    if gh_result and gh_result.stdout:
        data, status = _parse_response_with_headers(gh_result.stdout)
        # Only a definitive answer ends the attempt. `fetch` treats any gh
        # failure as "try curl next", and dropping that here would regress
        # environments where gh holds a stale token but an unauthenticated
        # curl still answers: an auth failure would surface as "unknown",
        # which callers now escalate into a hard failure.
        if status is not None and (200 <= status < 300 or status == 404):
            return data, status

    curl_cmd = ["curl", "-sS", "-H", "Accept: application/vnd.github+json"]
    curl_config = _curl_auth_config()
    if curl_config:
        curl_cmd += ["--config", "-"]
    curl_cmd += ["-w", "\n%{http_code}", f"{API}{endpoint}"]
    try:
        result = subprocess.run(
            curl_cmd,
            capture_output=True,
            input=curl_config,
            text=True,
            timeout=TIMEOUT,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None, None
    if result.returncode != 0 or not result.stdout:
        return None, None
    body, _, status_text = result.stdout.rpartition("\n")
    try:
        status = int(status_text)
    except ValueError:
        return None, None
    if not body.strip():
        return None, status
    try:
        return json.loads(body), status
    except json.JSONDecodeError:
        return None, status


def fetch_optional_json(endpoint):
    """Fetch optional JSON. Returns (data, found), with None found on ambiguity."""
    data, status = fetch_json_with_status(endpoint)
    if status == 404:
        return None, False
    if status == 200 and data is not None:
        return data, True
    return None, None


# GitHub resolves community health files from `.github/`, then the repository
# root, then `docs/`, taking the first hit.
HEALTH_DIRS = (".github/", "", "docs/")


def health_candidates(name):
    """Candidate paths for one health file, in GitHub's precedence order."""
    return tuple(f"{d}{name}" for d in HEALTH_DIRS)


_install_excepthook()
