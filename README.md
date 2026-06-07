# grok-brownfield

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Grok Build](https://img.shields.io/badge/Grok%20Build-skill-green)](https://docs.x.ai/build/features/skills-plugins-marketplaces)
[![Verify](https://github.com/kartikkabadi/grok-brownfield/actions/workflows/verify.yml/badge.svg)](https://github.com/kartikkabadi/grok-brownfield/actions/workflows/verify.yml)

**Audit, validate, and improve existing codebases you can run but cannot confidently judge.**

`/brownfield` is a [Grok Build](https://docs.x.ai/build/overview) agent skill for **brownfield** projects — apps and repos that already exist. You know how to use the product; you are not sure whether the architecture, tests, security, or implementation are actually correct. Brownfield treats existing code as **evidence, not ground truth**, runs parallel specialist analysis, produces a consolidated improvement design doc, and optionally executes the plan as isolated PRs.

> **For non-technical builders:** If you can demo the app but worry something is “built wrong” under the hood, brownfield is your structured second opinion — without you reading every file.

---

## Before you begin

| Requirement | Why |
|-------------|-----|
| **[Grok Build](https://docs.x.ai/build/overview)** with `spawn_subagent` | Orchestrator delegates all substantive work |
| **Git workspace** | Analysis and execute paths expect a repo |
| **Bundled Grok skills** (`~/.grok/bundled/skills/`) | Personas: design-doc-writer, design-doc-reviewer, implementer, reviewer, security-auditor |
| **AskQuestion** (or equivalent) | Assumption escalation in Phase 2a |
| **Optional:** `gt` (Graphite), `gh` (GitHub CLI) | Stack assembly and `--auto-pr` |

**Windows:** Paths below use Unix `~/.grok/...`. On Windows, use `%USERPROFILE%\.grok\skills\brownfield` (or run Grok Build under WSL with the Unix paths).

**Contributors / CI:** Verify scripts also work with the repo fixture at `fixtures/bundled-skills/` — no full Grok install required. See [Verification](#verification).

---

## Non-technical quick path

Just want a health check on a project you can run but do not fully trust?

1. **Install** the skill (clone step below) and **reload Grok Build** (see Quick start).
2. **Open your project** in Grok Build so the agent can see the repo.
3. In the **Grok Build chat input** (where you normally talk to the agent), type:
   ```
   /brownfield ./path-to-your-project
   ```
   Use the folder path to your codebase — ask a developer for the exact path if unsure.
4. **Wait for the design doc** — brownfield stops after the improvement plan unless you add `--execute`.
5. **Involve a developer** when the report mentions PRs, security findings, or `--execute`.

---

## The problem brownfield solves

| You can… | You cannot… | Brownfield gives you… |
|----------|---------------|------------------------|
| Run and click through the app | Judge if architecture matches intent | Intent brief + assumption register |
| Ship features in a legacy repo | Tell if tests or security are adequate | Parallel specialist audits |
| Describe what “should” happen | Know if the code actually does that | Design doc with PR plan |
| Want fixes, not just a report | Safely implement across many files | Optional `--execute` with reviewers |

**Core philosophy:** Specialists question assumptions, flag low-confidence areas, and escalate blocking questions to you before recommending changes.

---

## Quick start

### Install (Grok Build)

**Recommended — full repo** (includes verify scripts for development):

```bash
git clone https://github.com/kartikkabadi/grok-brownfield.git
cd grok-brownfield
cp -r . ~/.grok/skills/brownfield/
```

**Skill file only** (runtime minimum — no local verify tooling):

```bash
git clone https://github.com/kartikkabadi/grok-brownfield.git
cd grok-brownfield
mkdir -p ~/.grok/skills/brownfield
cp SKILL.md ~/.grok/skills/brownfield/
```

**Reload Grok Build** so the skill is discovered:

1. Save any open work in your Grok Build session.
2. **Restart the Grok Build app**, or use your environment’s **Reload skills / Refresh skills** action (often in settings or the command palette).
3. Confirm `/brownfield` appears in skill autocomplete when you type `/` in the agent chat input.

If the skill does not appear, verify `~/.grok/skills/brownfield/SKILL.md` exists and reload again.

### Run

**Where to type this:** In the **Grok Build agent chat input** (the main prompt where you instruct the coding agent) — not your system shell, unless your Grok setup documents a CLI entry point.

Point `project path` at the root of the Git repo you want audited (the folder that contains `.git`):

```
/brownfield ./my-repo
/brownfield --effort 3 ./my-repo "focus on checkout flow"
/brownfield --execute --effort 4 ./my-repo
```

---

## Glossary

| Term | Meaning |
|------|---------|
| **PR** | Pull request — a proposed code change on GitHub (or similar) |
| **Worktree** | An isolated copy of the repo used to implement one PR without touching your main checkout |
| **Graphite (`gt`)** | Optional CLI for stacked PR workflows |
| **DAG** | Directed acyclic graph — PR dependency order in the execution plan |
| **Persona** | Specialist instructions loaded from bundled Grok skills (e.g. security-auditor) |

---

## Workflow

```mermaid
flowchart TD
    A["/brownfield invocation"] --> B["Phase 0: Setup<br/>umask, run ID, personas"]
    B --> C["Phase 1: Intent Discovery<br/>What should this project do?"]
    C --> D["Phase 2: Assumption-Aware Analysis<br/>Parallel specialists (architecture, code, tests, security, docs)"]
    D --> E{"Blocking assumptions?"}
    E -->|Yes| F["Phase 2a: Escalation<br/>Ask user to confirm"]
    E -->|No| G["Phase 3: Consolidated Design Doc<br/>Gaps, risks, PR plan DAG"]
    F --> G
    G --> H["Phase 4: Design Review Loop<br/>Writer ↔ reviewer until 0 open issues"]
    H --> I["Phase 4b: Summary & open questions"]
    I --> J{"--execute?"}
    J -->|No| K["Final Report<br/>Design doc + artifacts"]
    J -->|Yes| L["Phase 5: Inline Execute<br/>Worktree PRs, multi-reviewer loops, stack assembly"]
    L --> M["Phase 6: Post-Implementation Verify"]
    M --> K
```

**Deliverables** (kept by default under `/tmp/grok-brownfield-*`):

- Intent brief
- Assumptions register
- Merged analysis
- **Design document** (main output) with PR plan
- Optional verify report after `--execute`

---

## Comparison: brownfield vs `/implement` vs `/design`

| | `/brownfield` | `/design` | `/implement` |
|---|---------------|-----------|--------------|
| **Starting point** | Existing repo you may not understand | New feature or change idea | Approved design / plan |
| **Treats code as** | Evidence to question | N/A (greenfield) | Instructions to follow |
| **Analysis** | Multi-specialist audit + assumptions | Requirements → design | Single-task implementation |
| **Output** | Improvement design doc + optional PRs | Design doc | Code changes |
| **Best for** | “Is this built correctly?” | “How should we build X?” | “Build X per this plan” |

Brownfield often **feeds** implement: Phase 5 inline execute uses worktree-isolated implementers and effort-scaled reviewers; `--delegate-execute` falls back to `/execute-plan`.

---

## Effort vs `--execute`

Two independent knobs:

### `--effort N` (1–5) — rigor in analysis **and** execution

| Effort | Analysis (pass 1) | Analysis (pass 2) | Execute reviewers per PR (inline) |
|--------|-------------------|-------------------|-----------------------------------|
| **1** | Architecture | Code only* | 1 |
| **2** | + Product-Intent | + Tests | 2 |
| **3** | (same as 2) | + Documentation | 3 |
| **4** | (same as 2) | + Security | 5 |
| **5** | (same as 2) | + second Code specialist | 6 |

\*Intent keywords (e.g. “security”, “auth”) can add Tests, Security, or Documentation even at effort 1.

### `--execute` — run the PR plan after design review passes

- **Without `--execute`:** Stops after design doc reaches **0 open review issues** (audit + plan only).
- **With `--execute`:** Runs Phase 5–6 — worktree-isolated PRs, per-PR reviewer loops, Graphite or plain-git stack assembly, post-implementation verification.
- **`--delegate-execute`:** Lower-rigor fallback; delegates to `/execute-plan` at effort 1 per PR (requires `--execute`).

---

## Example invocations

```bash
# Quick audit — architecture + code review, design doc only
/brownfield ./my-saas-app

# Deeper audit with security and docs specialists
/brownfield --effort 4 ./my-saas-app "review payment and auth flows"

# Full pipeline: audit → design → implement → verify
/brownfield --execute --effort 4 ./my-saas-app

# Resume a crashed execute run (ID from state file)
/brownfield --resume a1b2c3d4

# Force plain git + auto draft PRs (no Graphite)
/brownfield --execute --no-graphite --auto-pr ./my-repo
```

---

## Flags reference

| Flag | Default | Purpose |
|------|---------|---------|
| `--effort N` (1–5) | 1 | Scales analysis specialists and per-PR implementation reviewers |
| `--execute` | off | After design review, run the PR plan (inline by default) |
| `--delegate-execute` | off | Force `/execute-plan` instead of inline execute (effort 1 per PR; requires `--execute`) |
| `--no-graphite` | off | Plain-git stack even when Graphite (`gt`) is installed |
| `--auto-pr` | off | In plain-git mode, create draft PRs via `gh pr create` when available |
| `--resume ID` | — | Resume crashed runs; restores effort and flags from state |
| `--concurrency N` (1–8) | 4 | Max parallel PR implementers during `--execute` |
| `--cleanup-deliverables` | off | Remove state file and verify artifact after final report |

---

## Resume guide

State file: `/tmp/grok-brownfield-state-<BROWNFIELD_ID>.json` (8 hex chars)

| `phase` in state | Command |
|------------------|---------|
| `execute_inline` (or legacy `execute`) | `/brownfield --resume <ID>` |
| `execute_pending` | `/brownfield --resume <ID>` |
| `execute_delegated` | `/execute-plan --resume <execute_plan_id>` (read id from brownfield state) |
| `verify` | `/brownfield --resume <ID>` |

On resume, CLI `--effort` / `--execute` flags are ignored; values are restored from the state file.

---

## Verification

Structure and regression checks ship with the repo. **GitHub Actions** runs the same scripts on every push/PR (see [`.github/workflows/verify.yml`](.github/workflows/verify.yml)).

```bash
cd grok-brownfield
bash scripts/bootstrap_bundled_fixture.sh   # validates fixtures/bundled-skills
bash scripts/verify_skill.sh                # structure, patterns, persona resolution
bash tests/test_verify_skill.sh             # negative / regression tests
```

Both verify commands should exit `0`. CI uses `fixtures/bundled-skills/` via `BUNDLED_SKILLS_ROOT`; locally, scripts prefer `~/.grok/bundled/skills/` when installed, then fall back to the fixture.

---

## Repository layout

```
grok-brownfield/
├── README.md
├── SKILL.md              # Full skill specification (~2000 lines)
├── LICENSE               # MIT
├── NOTICE                # Runtime bundled-skills dependency boundary
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
├── SECURITY.md
├── AGENTS.md
├── fixtures/
│   └── bundled-skills/   # Portable verify fixture (CI + contributors)
├── scripts/
│   ├── verify_skill.sh
│   ├── resolve_bundled_root.sh
│   └── bootstrap_bundled_fixture.sh
├── tests/
│   └── test_verify_skill.sh
└── .github/
    ├── workflows/verify.yml
    ├── ISSUE_TEMPLATE/
    └── pull_request_template.md
```

---

## Design philosophy

Brownfield is built around **assumption-checking**, not rubber-stamping:

1. **Existing code is evidence** — behavior may be accidental, outdated, or wrong.
2. **Parallel specialists** — architecture, product intent, code, tests, security, documentation.
3. **Confidence levels** — low-confidence blocking assumptions escalate to the user.
4. **Review loops** — design doc is reviewed until zero open issues.
5. **Optional execution** — same effort knob scales implementation reviewers when you are ready to ship fixes.

See [SKILL.md](./SKILL.md) for the complete orchestration spec.

---

## Contributing

Issues and PRs welcome. See [CONTRIBUTING.md](./CONTRIBUTING.md), [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md), and [AGENTS.md](./AGENTS.md).

---

## License

MIT © [Kartik Kabadi](https://github.com/kartikkabadi) — see [LICENSE](./LICENSE).

Runtime bundled Grok personas are **not** covered by this repo’s MIT license — see [NOTICE](./NOTICE).