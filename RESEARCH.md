# Research write-up: what “good OSS citizenship” should mean for agentic AI contributors

## Framing the problem

The current backlash from open source maintainers is not mainly about whether AI was used. It is about review burden, trust, and process. In GitHub’s January 27, 2026 community discussion on low-quality contributions, GitHub summarized maintainer feedback as spending substantial time on contributions that fail project guidelines, are frequently abandoned shortly after submission, and are often AI-generated. GitHub then followed that with new repository settings announced on February 13, 2026 that let maintainers disable pull requests entirely or restrict them to collaborators only. Around the same time, tldraw announced on January 15, 2026 that it would begin automatically closing pull requests from external contributors, citing a recent increase in AI-generated PRs with weak context and little follow-up engagement. ([github.com](https://github.com/orgs/community/discussions/185387))

Recent empirical work points in the same direction. A study of 33,000+ agent-authored pull requests, accepted at MSR 2026, found that not-merged agent PRs tend to be larger, touch more files, and often fail CI; the authors also identified rejection reasons such as duplicate PRs, unwanted feature implementations, lack of meaningful reviewer engagement, and agent misalignment. A separate 2026 study on 33,707 AI-generated PRs found a two-regime pattern: simple narrow tasks are often merged quickly, while many agents stall during iterative review, creating what the authors call an “attention tax” on maintainers. Another recent study found that successful integration of agent-authored PRs depends strongly on reviewer engagement and convergence during review, while larger changes and coordination-disrupting actions such as force-pushes are associated with lower merge likelihood. ([arxiv.org](https://arxiv.org/abs/2601.15195))

The practical implication is that a “good OSS citizen” tile should not optimize for “produce code fast.” It should optimize for **maintainer trust and review efficiency**: follow local process, keep scope tight, make review cheap, and stay engaged through the full feedback loop. That is the research-supported problem definition. ([github.com](https://github.com/orgs/community/discussions/185387))

## Finding 1: repo-local process is the real contract

GitHub’s own contributor-guideline documentation is explicit about the function of `CONTRIBUTING.md`: for contributors, it helps verify that they are submitting well-formed pull requests and useful issues; for both contributors and maintainers, it reduces the time and hassle caused by improperly created PRs and issues that must be rejected and resubmitted. GitHub also surfaces `CONTRIBUTING.md` prominently in the UI and supports organization-wide default community health files, including `CONTRIBUTING`, so these files are not incidental documentation; they are part of the project’s operating contract. GitHub’s template system does the same for issues and pull requests by standardizing what information contributors must provide. ([docs.github.com](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/setting-guidelines-for-repository-contributors))

That makes your first proposed rule—read and adhere to `CONTRIBUTING.md`—not just sensible but foundational. A generic coding agent cannot be a good OSS citizen unless it begins by discovering the repository’s local contract: contribution guidelines, issue and PR templates, changelog rules, security policy, AI policy, and any design or governance documents linked from those files. Projects differ too much for “global best practices” alone to be enough. ([docs.github.com](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/setting-guidelines-for-repository-contributors))

## Finding 2: reading prior accepted and rejected work is a legitimate research step

Open Source Guides explicitly recommends reading a project’s issue tracker, pull/merge requests, and discussion archives because doing so gives contributors “a good picture of how the community thinks and works.” GitHub also provides built-in filtering and search for issues and pull requests by state, review status, labels, linked issue, check status, merged/unmerged state, and sorting criteria. Together, those sources support a strong design principle for the tile: before opening a PR, the agent should mine recent project history to understand what kinds of changes get accepted, what kinds get rejected, how maintainers ask for context, what testing evidence they expect, how large PRs usually are, and which reasons recur in closures or “changes requested” reviews. ([opensource.guide](https://opensource.guide/how-to-contribute/))

This is partly an inference rather than a rule stated verbatim by one source, but it is a grounded one. If CONTRIBUTING explains the formal rules and the PR/archive history shows how those rules are enforced in practice, then a responsible agent should use both. The archive is where local norms become visible. ([docs.github.com](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/setting-guidelines-for-repository-contributors))

## Finding 3: a good contributor knows when not to open a PR yet

GitHub distinguishes issues, pull requests, and discussions for different purposes: issues are for discussing bugs, planned improvements, and feedback; pull requests are for proposing specific changes. Major OSS projects reinforce that separation for substantial work. Django requires wider community discussion when a patch introduces new functionality or a design decision, especially around deprecations or breaking changes. Rust requires RFCs for “substantial” changes, while ordinary bug fixes and documentation improvements can go through the normal PR workflow. Kubernetes requires a KEP for each new feature. Gitea states that significant changes must go through a change proposal process and that pull requests should not be the place for architecture discussions. ([docs.github.com](https://docs.github.com/articles/about-discussions-in-issues-and-pull-requests))

This is one of the most important implications for the tile. A good OSS-citizen agent needs a **venue-selection step** before any coding: should this be a discussion, an issue, an RFC/KEP/change proposal, or a PR? Many “bad AI PRs” are not bad because the patch is syntactically wrong; they are bad because they skip the repo’s actual decision-making path. ([docs.djangoproject.com](https://docs.djangoproject.com/en/dev/internals/contributing/writing-code/submitting-patches/))

## Finding 4: accepted contributions are usually scoped, explicit, and test-backed

Project documents repeatedly emphasize clarity, scope control, and verification. Homebrew tells contributors to be explicit about context in issue and PR bodies, to link a tracking issue when the PR is part of a larger initiative, and to avoid bloated diffs. `pytest` asks contributors to enable pre-commit checks, run tests with `tox`, create a changelog entry when the change affects documented behavior, and add themselves to `AUTHORS` for non-trivial changes. Servo is unusually direct: “your PR won’t get accepted without a test.” Gitea requires contributors to review AI-generated code closely, test changes manually, add automated tests where feasible, and run the test suite before submitting. ([docs.brew.sh](https://docs.brew.sh/Maintainer-Guidelines))

These examples matter because they show that maintainers reward contributions that are cheap to review. The agent should therefore assume that “good citizenship” includes: keeping PRs small, linking prior context, explaining why the change exists, running repo-specific checks, adding or updating tests, and doing housekeeping such as changelog or metadata updates when the project expects them. These are not extras; in many projects they are part of the definition of a mergeable contribution. ([docs.brew.sh](https://docs.brew.sh/Maintainer-Guidelines))

## Finding 5: AI policy is local, and it varies widely

There is no single OSS norm on AI-assisted contribution. Ghostty allows AI use but requires full disclosure of the tool and extent of assistance, and it requires the human contributor to fully understand the code; it also says that AI-assisted issues and discussions must be human-reviewed and edited before submission. Gitea also allows AI-assisted contributions, but only with rules: include related issues or PRs in the prompt, review the generated code closely, test it manually, disclose which model was used, and do not use AI to answer maintainers’ questions during review. Servo takes a stricter approach and currently bans contributions generated by large language models or other probabilistic tools, citing maintainer burden and contributor understanding. In Cilium’s 2025 community discussion, maintainers noted that they had no written policy yet, but floated disclosure, originality, attribution, and the ability to reason through the submitted code as core standards. ([raw.githubusercontent.com](https://raw.githubusercontent.com/ghostty-org/ghostty/refs/heads/main/AI_POLICY.md))

This diversity is central to your thesis. Agents are not failing only because they use AI; they are failing because they often act as though every repo has the same norms. A good OSS-citizen tile has to begin with **AI policy discovery**. For one repo, the correct behavior may be “disclose and proceed carefully.” For another, it may be “AI-generated contributions are not acceptable here at all.” For yet another, it may be “AI is fine, but only if the human can fully own the change and handle review personally.” ([raw.githubusercontent.com](https://raw.githubusercontent.com/ghostty-org/ghostty/refs/heads/main/AI_POLICY.md))

## Finding 6: blanket rejection of AI-assisted work is too crude, but “AI wrote it” is not enough either

Recent empirical evidence does not support the claim that AI-assisted OSS contributions are inherently worthless. A 2025 study of 567 Claude Code PRs across 157 OSS projects found that 83.8% were eventually merged; however, only 54.9% of those merged PRs were integrated without further modification, and 45.1% required additional human revisions, especially around bug fixes, documentation, and project-specific standards. A separate 2025 study of 338 pull requests with self-admitted ChatGPT usage found that full adoption of ChatGPT code was rare, with a median integration rate of 25%; developers typically treated AI output as a starting point and refined or selectively integrated it. ([arxiv.org](https://arxiv.org/abs/2509.14745))

That evidence supports a nuanced position. “AI used” is not a reliable proxy for “bad contribution.” But “AI used” also does not excuse weak understanding, poor adaptation to local standards, or lack of follow-through in review. The research suggests that human oversight, project-specific adaptation, and review-time collaboration are what separate acceptable AI-assisted contributions from the ones maintainers resent. ([arxiv.org](https://arxiv.org/abs/2509.14745))

## Finding 7: trust starts before the pull request

A 2025 peer-reviewed study in *Empirical Software Engineering* analyzed about 1.8 million pull requests and 2.1 million issues across 20,052 GitHub projects in the NPM ecosystem. It found that active participation in issue-tracking systems, submitting pull requests, and collaborating with integrators and the ecosystem community all benefit contributors, especially newcomers. In other words, contributor trust is socially accumulated; it does not begin at the moment a PR appears. ([link.springer.com](https://link.springer.com/article/10.1007/s10664-025-10706-1))

For the tile, this means “good OSS citizenship” should include behavior before code is proposed: search for existing issues, join the right conversation, show awareness of project scope, and build local context. A drive-by autonomous patch with no prior grounding is fighting uphill against how OSS trust actually works. ([link.springer.com](https://link.springer.com/article/10.1007/s10664-025-10706-1))

## Synthesis

The research points to a clear conclusion: the core failure mode of many agentic OSS contributions is not just code quality. It is **social and procedural misalignment**. Maintainers are reacting to PRs that ignore local rules, skip prior discussion, arrive oversized, lack tests or housekeeping, obscure AI use when disclosure matters, and then go quiet during review. The empirical literature and project documents both show that successful contributions tend to be narrow, contextualized, verifiable, and owned by a contributor who can stay in the loop until convergence. ([github.com](https://github.com/orgs/community/discussions/185387))

So the most defensible design goal for your tile is this: **teach the agent to behave like a careful, accountable OSS contributor, not like an autonomous patch cannon**. In practice, that means the tile should force the agent to discover repo-local rules first, inspect prior accepted and rejected work, choose the right pre-PR venue, keep scope tight, satisfy testing and documentation gates, disclose AI use when required, and ensure a human can personally explain and defend every line through review. ([docs.github.com](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/setting-guidelines-for-repository-contributors))

## Research-backed requirements for the tile

1. **Read the repository’s contract first.** Parse `CONTRIBUTING.md`, issue and PR templates, security policy, governance docs, and any AI policy before suggesting code. ([docs.github.com](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/setting-guidelines-for-repository-contributors))

2. **Inspect local precedent.** Review recent merged, closed, and “changes requested” PRs to infer accepted scope, expected evidence, and common rejection patterns. ([opensource.guide](https://opensource.guide/how-to-contribute/))

3. **Choose the right venue before coding.** Route substantial or architectural changes to an issue, discussion, RFC, KEP, or project-specific proposal process instead of opening a PR immediately. ([docs.github.com](https://docs.github.com/articles/about-discussions-in-issues-and-pull-requests))

4. **Prefer small, explicit PRs.** Link the relevant issue, explain the motivation, keep diffs narrow, and avoid bundling unrelated cleanup. ([docs.brew.sh](https://docs.brew.sh/Maintainer-Guidelines))

5. **Meet repo-specific verification gates.** Run the project’s lint/test workflow, add tests where needed, and update changelogs or metadata when the repo expects them. ([docs.pytest.org](https://docs.pytest.org/en/stable/contributing.html))

6. **Handle AI use according to local policy.** That may mean disclose-and-own, or it may mean do not submit AI-generated content at all. ([raw.githubusercontent.com](https://raw.githubusercontent.com/ghostty-org/ghostty/refs/heads/main/AI_POLICY.md))

7. **Require human ownership through review.** The contributor must be able to explain the change, respond personally to questions, and keep iterating until the review converges or the change is withdrawn. ([raw.githubusercontent.com](https://raw.githubusercontent.com/ghostty-org/ghostty/refs/heads/main/AI_POLICY.md))

8. **Optimize for maintainer attention, not maximum autonomy.** Use gating, scope limits, and local-rule checks to avoid opening PRs that are likely to waste review time. ([github.com](https://github.com/orgs/community/discussions/185387))

One caveat: several of the 2025–2026 studies on agent-authored PRs are recent papers and preprints; the strongest project-process evidence here comes from official project documentation and GitHub’s own docs, while the empirical literature is best read as fast-moving evidence that supports the same general conclusion. ([arxiv.org](https://arxiv.org/abs/2601.15195))

## Finding 8: the agent instruction file ecosystem is already fragmenting

Beyond `CONTRIBUTING.md`, a parallel ecosystem of agent-specific instruction files has emerged. These files tell AI tools how to behave in a given repo, but each tool has its own convention:

| File | Tool |
|------|------|
| `CLAUDE.md` | Claude Code |
| `AGENTS.md` | Cross-tool (Agentic AI Foundation emerging standard) |
| `.cursorrules` / `.cursor/rules/` | Cursor |
| `.github/copilot-instructions.md` | GitHub Copilot |
| `HOWTOAI.md` | Block’s goose project |
| `PROMPTING.md` | Proposed by the Responsible Vibe Coding Manifesto |

A good OSS-citizen agent should scan for ALL of these, not just its own format. If a repo has `.cursorrules` but no `CLAUDE.md`, the instructions in `.cursorrules` are still the maintainers’ intent and should be respected. The same applies in reverse. ([agents.md](https://agents.md/), [github.blog](https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/))

## Finding 9: code convention files are part of the contract

The repo-local contract extends beyond prose documents into machine-readable configuration that agents should discover and obey automatically:

- **Formatting**: `.editorconfig`, `.prettierrc`, `rustfmt.toml`, `.clang-format`
- **Linting**: `.eslintrc.*`, `eslint.config.*`, `pyproject.toml` (ruff/black/flake8 sections)
- **Commit conventions**: `commitlint.config.*`, `.pre-commit-config.yaml`
- **CI enforcement**: `.github/workflows/`, `Makefile`, `justfile`, `Taskfile`
- **Ownership**: `CODEOWNERS` (tells the agent who will review which files)
- **Automated PR checks**: `Dangerfile` / `danger.config.*`

If no config files exist, the agent should analyze 3–5 files in the same directory and match their patterns — naming, indentation, comment style, import ordering. One real code snippet from the project beats any generic "best practice." ([editorconfig.org](https://editorconfig.org/), [conventionalcommits.org](https://www.conventionalcommits.org/en/v1.0.0/))

## Finding 10: DCO/CLA requirements are a hard boundary the agent must not cross

Many projects require a Developer Certificate of Origin sign-off (`Signed-off-by:` line) or a Contributor License Agreement. These are legal assertions that only a human can make. The Linux kernel’s coding assistants policy is explicit: the agent must NEVER add `Signed-off-by:` tags on behalf of a contributor. Similarly, CLA bots (CLA assistant, Microsoft CLA, CLAHub) require human action before a PR can merge.

The agent should detect these requirements (presence of a `DCO` file, CLA bot configuration in `.github/`, or sign-off patterns in recent commits) and inform the human that they need to handle this step personally. Forging attribution is treated as a permanent-ban offense in projects like Jellyfin, which has "zero tolerance for code theft and bad-faith attribution attempts." ([docs.kernel.org](https://docs.kernel.org/process/coding-assistants.html), [jellyfin.org](https://jellyfin.org/docs/general/contributing/llm-policies/))

## Finding 11: some issue labels carry special restrictions

LLVM explicitly forbids using AI tools to fix issues labeled "good first issue," reasoning that these exist as learning opportunities for human newcomers. An agent that sweeps up beginner-friendly issues is not helping — it is removing the onramp that projects use to grow their contributor base.

More broadly, the agent should check issue metadata before starting work: is the issue assigned? Has someone commented "I’d like to work on this"? Is it labeled as internal, or blocked on a design decision? Submitting a competing PR on an assigned issue is bad etiquette regardless of whether AI was involved, but agents make it worse by making it trivially easy to do at scale. ([llvm.org](https://llvm.org/docs/AIToolPolicy.html))

## Finding 12: slop detection tools exist and the agent should know how to not trigger them

Maintainers are deploying automated defenses:

| Tool | What It Does |
|------|-------------|
| **anti-slop** (GitHub Action) | 31 behavioral checks to detect and auto-close AI slop PRs; catches 98% in testing |
| **Open Slop** (GitHub Action) | Forensic triage using velocity, shotgunning, and ghost-contributor signals — no AI-to-detect-AI |
| **contributor-report** (GitHub Action) | Evaluates contributor quality using objective GitHub metrics |

These tools flag patterns like: opening many PRs across unrelated repos in quick succession, submitting and vanishing, large unfocused diffs, and characteristic AI verbosity. An agent that follows the other rules in this document will naturally avoid triggering these detectors, but awareness of their existence is useful context. The signals they check are essentially a machine-readable summary of what maintainers consider slop. ([github.com/peakoss/anti-slop](https://github.com/peakoss/anti-slop), [github.com/dr-alberto/open_slop](https://github.com/dr-alberto/open_slop))

## Finding 13: agent metafiles must never leak into contributions

Jellyfin’s LLM policy explicitly states: "no LLM metafiles (`.claude` configs, editor artifacts)." The agent should ensure that directories like `.claude/`, `.cursor/`, `.aider/`, and similar tool-specific state are in `.gitignore` and never included in commits or PR diffs. Leaking these files is a signal that the contributor did not review their own submission. ([jellyfin.org](https://jellyfin.org/docs/general/contributing/llm-policies/))

## Finding 14: a living reference of AI policies already exists

The repository [melissawm/open-source-ai-contribution-policies](https://github.com/melissawm/open-source-ai-contribution-policies) maintains a comprehensive, community-updated list of projects with explicit AI contribution policies, categorized by stance (ban, restriction, disclosure requirement, acceptance with conditions). As of early 2026, it tracks dozens of projects. This is the closest thing to a registry of AI norms across the OSS ecosystem, and the tile should reference it as an authoritative source for policy lookup when a project’s own docs are silent. ([github.com/melissawm/open-source-ai-contribution-policies](https://github.com/melissawm/open-source-ai-contribution-policies))

## Finding 15: security-aware code generation is a specific responsibility

The OpenSSF published a "Security-Focused Guide for AI Code Assistant Instructions" that defines concrete rules agents should follow: never hardcode secrets or API keys, use parameterized queries for all database access, validate all external inputs, use HTTPS by default, prefer well-known libraries over obscure dependencies, never hallucinate package names (verify packages exist before adding them as dependencies), and pin dependency versions rather than using `latest` tags. The cURL bug bounty shutdown — caused by AI-generated security reports that manufactured severity where none existed — is a cautionary tale: agents must NEVER generate security vulnerability reports that the human has not personally reproduced. ([best.openssf.org](https://best.openssf.org/Security-Focused-Guide-for-AI-Code-Assistant-Instructions.html))

## Finding 16: the asymmetric effort problem is the root economic failure

The fundamental dynamic, surfaced across nearly every maintainer complaint and confirmed by the MSR 2026 empirical work, is an economic asymmetry: AI reduced the cost of generating a contribution to near-zero while doing nothing to reduce the cost of reviewing one. A PR that takes 30 seconds to generate can take hours to properly evaluate and reject. This means a slop PR does not need to land to cause harm — it just needs to look plausible enough to demand careful attention. The tile’s design should be evaluated against this metric: does each rule reduce the review burden on maintainers, or does it only improve the contributor’s experience? Rules that only help the contributor are insufficient. ([thenewstack.io](https://thenewstack.io/curls-daniel-stenberg-ai-is-ddosing-open-source-and-fixing-its-bugs/))

## Updated research-backed requirements for the tile

The original eight requirements stand. The additional findings support these supplementary requirements:

9. **Discover all agent instruction files, not just your own format.** Scan for `CLAUDE.md`, `AGENTS.md`, `.cursorrules`, `.github/copilot-instructions.md`, `HOWTOAI.md`, and `PROMPTING.md`. Treat any of them as maintainer intent.

10. **Obey machine-readable convention files.** Parse `.editorconfig`, linter configs, formatter configs, `commitlint`, pre-commit hooks, and `CODEOWNERS` to match the project’s style exactly.

11. **Detect and surface legal requirements.** Flag DCO sign-off requirements and CLA obligations to the human. Never forge `Signed-off-by:` or other legal attestations.

12. **Respect issue metadata.** Check assignment, claimed-by comments, and labels like "good first issue" (which some projects reserve for human learners) before starting work.

13. **Never include agent metafiles in contributions.** Ensure `.claude/`, `.cursor/`, and similar directories are excluded from commits.

14. **Consult the living policy registry.** When a project’s own docs are silent on AI policy, check [melissawm/open-source-ai-contribution-policies](https://github.com/melissawm/open-source-ai-contribution-policies) for known stances.

15. **Follow security-aware generation rules.** No hardcoded secrets, no hallucinated package names, no AI-generated vulnerability reports without human reproduction.

16. **Evaluate every behavior against the review-burden metric.** The tile’s purpose is to reduce maintainer cost, not to maximize agent output.
