## Description

When the cache layer is configured with `ttl=0`, every read still returns a stale entry from the eviction queue instead of treating the value as expired. The behavior changed between 2.4.0 and 2.4.1 — on 2.4.0 the same configuration returned `None` and triggered a re-fetch.

## Environment

- Library: 2.4.1
- Python: 3.11.7
- Linux 6.8 / x86_64

## Reproduction

1. Initialise the cache with `Cache(ttl=0)`.
2. Insert any key/value pair.
3. Read the same key.
4. The read returns the inserted value instead of `None`, even though `ttl=0` should mean "do not retain".

## Expected

`Cache(ttl=0)` should never serve a stored value — every read should miss and re-fetch.

## Logs / extra context

```
2026-04-26 09:14:11 DEBUG cache.read hit key=abc value=stale
```
