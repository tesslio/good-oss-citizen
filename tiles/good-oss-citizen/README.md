# good-oss-citizen

[![tessl](https://img.shields.io/endpoint?url=https%3A%2F%2Fapi.tessl.io%2Fv1%2Fbadges%2Ftessl-labs%2Fgood-oss-citizen)](https://tessl.io/registry/tessl-labs/good-oss-citizen)

Rules, skills, and scripts that teach AI agents how to contribute to open source projects without being the villain.

## Install

```
tessl install tessl-labs/good-oss-citizen
```

Install on your fork of whatever OSS project you're contributing to. The tile loads only in that project's context — switch to your own codebase and it isn't there.

## What it does

AI agents write working code but ignore everything around it: contribution guidelines, AI policies, prior rejected PRs, claimed issues, DCO requirements, changelog updates. This tile teaches the agent to check all of that before submitting.

**Without the tile:** 15% on OSS contribution process (while writing perfect code).
**With the tile:** 99%.

## How it works

The tile has three layers:

- **Rules** (always-on, ~2.8k tokens) — the commandments. Never forge a DCO sign-off, never submit without human review, respect AI bans, never write code for a claimed issue. These fire regardless of which skill activated.
- **Skills** (on-demand, ~5.3k tokens) — the scripture. Detailed workflow guidance for recon (scan the repo before writing code), propose (pick the right venue), and preflight (pre-submission checklist).
- **Scripts** (19 commands) — the rituals. Deterministic steps that fetch structured data from the GitHub API: policy files, issue comments, commit conventions, prior rejected PRs, CODEOWNERS, legal requirements. Scripts fetch, the model interprets.

## Research

Every rule and skill instruction traces back to documented failure modes from real OSS projects. See [RESEARCH.md](RESEARCH.md) for all 16 findings with sources.

## Blog posts

- [Our AI is the bright kid with no manners](/link-to-part-1) — why AI PRs fail and what the tile does about it
- [Our AI is the bright kid with no manners, part 2](/link-to-part-2) — how I built and tested the tile

## For maintainers

You don't have to ban AI. Add this to your README or CONTRIBUTING.md:

> We accept considerate AI-assisted contributions. Install `tessl install tessl-labs/good-oss-citizen` first.

## Links

- [Tile on Tessl registry](https://tessl.io/registry/tessl-labs/good-oss-citizen)
- [Source on GitHub](https://github.com/tesslio/good-oss-citizen)
