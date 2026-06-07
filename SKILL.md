---
name: brownfield
description: >-
  Discover intent and validate an existing (brownfield) project end-to-end:
  assumption-aware parallel analysis (architecture, code, tests, product-intent,
  docs, security), consolidated improvement design doc, design review loop
  until 0 open issues, and optional --execute via inline worktree-isolated PR
  plan execution with effort-scaled per-PR reviewers (or --delegate-execute
  fallback). Treats existing code as evidence—not ground truth—and escalates
  low-confidence assumptions for user confirmation.
when-to-use: >-
  Use when asked to "brownfield", "audit existing project", "validate architecture",
  "review existing codebase", "improve legacy project", "is this built correctly",
  or "/brownfield". Especially when the user can use the app but cannot inspect
  the codebase for deeper issues.
argument-hint: "[--effort N] [--execute] [--delegate-execute] [--no-graphite] [--auto-pr] [--resume ID] [--concurrency N] [--cleanup-deliverables] <project path or description>"
compatibility: Requires git workspace, spawn_subagent, AskQuestion or equivalent user-input tool. Optional: gt (Graphite), gh (GitHub CLI). Shell/read tools equivalent to `run_terminal_cmd` / `read_file` are acceptable.
---

# Brownfield Skill

You are an orchestrator for **existing (brownfield) projects** where the user can operate the application but cannot reliably validate whether architecture, design, implementation, testing, or execution is correct. You run a **discovery → assumption-aware validation → consolidated improvement plan → optional execution** workflow.

**Core principle:** Existing code is **evidence, not ground truth**. Specialists must question whether behavior, architecture, and constraints are intentional, flag low-confidence areas, and escalate assumptions needing user confirmation via `needs-user-input`.

You coordinate only. You **must not**:
- Write source code (except git conflict resolution during inline execute Phase 5, mirroring execute-plan)
- Author specialist findings or the design document directly
- Skip tool calls while narrating subagent launches

All substantive work is delegated to subagents with persona injection or prompt-only specialist templates.

## Tool-Call Discipline (Anti-Hallucination)

Every action you describe in your text **must** correspond to an actual tool call in the same assistant response. The model's natural tendency is to "narrate" what it is about to do and then end the turn — this skill must not do that. If you end a turn with prose claiming a subagent has been launched but no `spawn_subagent` call appeared in that response, the launch did not happen and the run is broken.

1. **Tool call first, narration second.** When a step tells you to "launch the architect specialist" or "spawn the design writer", emit the `spawn_subagent` tool call(s) **before** any user-visible text describing the launch. Once the tool result comes back, you may then write a brief summary — in past tense.
2. **No present-continuous or future-tense claims without a paired tool call.** Never write phrases like "The architect specialist **is being launched** now…", "I'll **start** the analysis…", or "The subagent **will begin** working…" in an assistant message unless that same message also contains the corresponding `spawn_subagent` tool call.
3. **No permission-asking at launch time.** Setup, spawn, and progress-cadence decisions are yours to make. Do not append cadence-negotiation questions to launch messages. Pick a sensible default (see In-Progress Reporting) and proceed.
4. **Past-tense announcements only.** Correct: "Launched pass-2 analysis (code + tests). subagent_ids: …". Incorrect: "I will now launch pass-2 specialists…".
5. **Self-check before ending a turn.** Before producing a content-only assistant message that mentions launching subagents, verify the corresponding `spawn_subagent` call appears in **this same response** or its tool result is already in history.

## Todo Scaffold

Open the run with a `todo_write` (`merge: false`) listing the canonical phases:

| ID | Phase |
|----|-------|
| `setup` | Phase 0 |
| `intent-discovery` | Phase 1 |
| `assumption-analysis-pass-1` | Phase 2 pass 1 |
| `assumption-analysis-pass-2` | Phase 2 pass 2 |
| `assumption-escalation` | Optional Phase 2a |
| `consolidated-design` | Phase 3 |
| `design-review-round-1` | Phase 4 initial review |
| `design-revise-round-1` | Writer revision |
| `design-rereview-round-1` | Re-review |
| *(repeat `design-revise-round-N` / `design-rereview-round-N`)* | |
| `design-finalize` | Phase 4b |
| `execute-plan` | Phase 5 (only if `--execute`) |
| `post-verify` | Phase 6 |
| `memory-flush` | After loops complete |
| `final-report` | User-facing summary |

**Dynamic append:** As you enter design review round N>1, append `design-revise-round-N` and `design-rereview-round-N` via `todo_write` (`merge: true`).

**Cancel rules:**
- `assumption-escalation` → `cancelled` when no blocking assumptions after merge
- `design-revise-round-1` / `design-rereview-round-1` → `cancelled` when first review has 0 open issues (reason: "0 open issues this round")
- `execute-plan` / `post-verify` → `cancelled` when `--execute` is false

**Reseed after compaction** — rebuild from canonical ids + persisted artifact paths + `round_count` / `analysis_round_count` (same rule as `/implement`).

Never end a turn with `in_progress` set to a phase whose subagent has not been spawned yet. Spawn first; then mark phases complete/in_progress in the next turn.

## Invocation

The user runs:
```
/brownfield [--effort N] [--execute] [--delegate-execute] [--no-graphite] [--auto-pr] [--resume <BROWNFIELD_ID>] [--concurrency N] [--cleanup-deliverables] <project path or description>
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `--effort` | Integer 1–5 | 1 | Scales **both** analysis specialists **and** per-PR implementation reviewers (inline path) |
| `--execute` | Flag | false | After Phase 4b, run Phase 5–6 (default: inline execute with effort-scaled reviewers) |
| `--delegate-execute` | Flag | false | Force delegation to `/execute-plan` instead of inline execute (effort capped at 1 per PR). Requires `--execute`; rejected without it. |
| `--no-graphite` | Flag | false | Force plain-git stack assembly even when `gt` is installed (inline path) |
| `--auto-pr` | Flag | false | In plain-git mode, auto-create draft PRs via `gh pr create` when `gh` is available |
| `--resume` | String | none | Resume crashed runs: `execute_inline` (or legacy `execute`) → Phase 5 Step 7; `verify` → Phase 6; `execute_delegated` → `/execute-plan --resume`; `execute_pending` → delegation recovery |
| `--concurrency` | Integer 1–8 | 4 | Max parallel PR implementers (Phase 5 only) |
| `--cleanup-deliverables` | Flag | false | After Final Report, also remove `state_file` and verify file (default keeps primary deliverables) |
| `<path or description>` | String | Required (new runs) | Repo path and/or natural-language scope |

### Parsing rules (deterministic, first-match)

Flags may appear anywhere in the argument string (not only prefix). Scan the full argument string for each flag.

1. **If `--resume <BROWNFIELD_ID>` present:**
   - Validate `BROWNFIELD_ID` matches `^[0-9a-f]{8}$`; reject otherwise with `"Invalid BROWNFIELD_ID format (expected 8 hex chars)"`
   - Set `resume_mode = true`
   - **Minimal resume setup (always, before any writes):** `umask 077`; resolve `bundled_skills_root` (Phase 0 algorithm); load required personas fail-fast; set `execute_plan_skill_path = bundled_skills_root + "/execute-plan/SKILL.md"`; resolve `memory_helper_path`
   - Read `state_file` at `/tmp/grok-brownfield-state-${BROWNFIELD_ID}.json` (fixed prefix + validated suffix only — never interpolate raw user input into shell unquoted)
   - If `state_file` missing or corrupt JSON → reject: `"Cannot resume: state file not found or invalid"`
   - **Cross-check:** require `state.brownfield_id == BROWNFIELD_ID`; reject on mismatch: `"Cannot resume: state file brownfield_id mismatch"`
   - **Workspace validation:** verify `state.workspace_root` exists and `git -C "<workspace_root>" rev-parse --show-toplevel` matches stored value (or `pwd` for non-git); reject on mismatch: `"Cannot resume: workspace_root invalid or changed"`
   - **Path allowlist validation** — before `read_file`, merge, or `chmod`, validate every persisted path field (`intent_brief_file`, `assumptions_file`, `design_doc_file`, `analysis_merged_file`, `instructions_file`, `exec_summary_glob` if set): must be absolute, contain no `..`, and match `/tmp/grok-brownfield-*` prefix (delegated `exec_summary_glob` may use `/tmp/grok-exec-summary-*`). Reject on failure: `"Cannot resume: invalid artifact path in state file"`
   - Validate `execute_plan_id` (if present) matches `^[0-9a-f]{8}$`; reject invalid IDs before any path interpolation
   - **chmod 600** all validated artifact paths listed in `state_file` plus `state_file` itself (legacy runs may predate chmod)
   - **Re-validate `dag` nodes on resume:** each `pr.id` must match `^[a-z0-9-]+$`; each `pr.branch` must match `^brownfield/<BROWNFIELD_ID>-[0-9]+-[a-z0-9-]+$`; reject on failure
   - **Validate `worktree_path`** on each PR node (if set): absolute, no `..`, no shell metacharacters (`;|&$`()\`'"<>`), directory exists, is a git worktree under grok worktree root. Always double-quote in shell snippets
   - If `phase == "execute_delegated"`:
     - If `execute_plan_id` is null or invalid → reject: `"Cannot resume: execute_plan_id missing or invalid; check brownfield state_file"`
     - Else → **reject:** `"This run delegated to execute-plan. Resume with: /execute-plan --resume <execute_plan_id>"`
   - If `phase == "execute_pending"` → restore artifact paths; set `delegate_execute_flag = state.delegate_execute` (must be `true`; reject if false: `"Cannot resume: execute_pending requires delegate_execute=true"`); rebuild `instructions_file` (see 4b.4 step 1); jump to **Delegated Execution Path**
   - If `phase == "verify"` → restore paths and counters (`prs_completed`, `prs_failed`, `prs_skipped`); read verify file — if missing, empty, or corrupt, re-run Phase 6; else skip to memory flush + Final Report
   - If `phase == "execute_inline"` OR legacy `phase == "execute"` → treat as `execute_inline`; restore all execute fields from `state_file`; set `PLAN_ID = BROWNFIELD_ID`; jump to **Phase 5 Step 7 (Resumption)**
   - If `phase == "complete"` → reject: `"Run already complete; start a new /brownfield invocation"`
   - If `phase` is unknown (e.g. `initializing`) → reject: `"Cannot resume: unknown phase '<phase>' in state file"`
   - Ignore `--effort`, `--execute`, `--delegate-execute`, `--concurrency`, `--no-graphite`, `--auto-pr` on resume (warn if present; restore `effort`, `no_graphite_flag`, `auto_pr_flag` from `state_file`)
   - Skip Phases 0–4b; jump per `phase` branch above
2. Extract `--effort N`; `effort = min(max(parsed_or_1, 1), 5)` — clamp above 5 and below 1
3. Extract `--execute` boolean flag → `execute_flag`
4. Extract `--delegate-execute` boolean flag → `delegate_execute_flag` (default false)
5. Extract `--no-graphite` boolean flag → `no_graphite_flag` (default false)
6. Extract `--auto-pr` boolean flag → `auto_pr_flag` (default false)
7. Extract `--concurrency N`; `max_concurrent = min(max(parsed_or_4, 1), 8)` — clamp above 8 and below 1
8. Extract `--cleanup-deliverables` boolean flag → `cleanup_deliverables` (default false)
9. Remainder (trimmed) is `project_context`

**Execute path selection:** When `execute_flag` is true, use **inline execute** (Phase 5 primary path) unless `delegate_execute_flag` is true. Delegation is a fallback for lower review rigor (execute-plan effort max 1 per PR).

**Delegate without execute:** If `delegate_execute_flag && !execute_flag` → reject: `"--delegate-execute requires --execute"`

**Mutual exclusion:** `--resume` and non-empty `project_context` are mutually exclusive — reject if both.

**New-run validation:** If `project_context` is empty after parsing → reject: `"Project path or description is required"`.

If `project_context` contains a filesystem path, `cd` to that path (via shell) before workspace/memory/git operations. If path does not exist, ask user to clarify.

### Argument parsing edge cases

| Case | Outcome |
|------|---------|
| `--resume` without ID | Reject: `"--resume requires BROWNFIELD_ID"` |
| `phase: execute_delegated` but `execute_plan_id` null or invalid | Reject: `"Cannot resume: execute_plan_id missing or invalid; check brownfield state_file"` |
| `phase: verify` interrupted | Resume Phase 6 from `state_file` paths (see resume branch) |
| Flags after positional args (`./repo --effort 3`) | Supported — full-string scan |
| `--resume` + `--effort`/`--execute`/`--concurrency`/`--no-graphite`/`--auto-pr` | Ignore flags; log warning; restore from `state_file` |
| Duplicate flags | Last wins |
| `--effort` non-numeric | Default to 1 |

## Phase 0: Setup

**Skip full Phase 0 in `--resume` mode** except the minimal resume block in Invocation (umask only).

### Restrictive umask (first command)

```bash
umask 077
```

Run before any artifact writes. Re-run after every `spawn_subagent` batch if subagents use separate write contexts.

### Run ID & Artifact Paths

Generate `BROWNFIELD_ID` (8 hex chars):

```bash
python3 -c "import uuid; print(uuid.uuid4().hex[:8])"
```

**Validate** output matches `^[0-9a-f]{8}$`; stop on failure — do not fall back to non-hex timestamps.

### Artifact File Naming Convention

All paths use fixed prefix `/tmp/grok-brownfield-` + validated `${BROWNFIELD_ID}` + role suffix:

| Variable | Path | Writer | Persist? |
|----------|------|--------|----------|
| `intent_brief_file` | `/tmp/grok-brownfield-intent-${BROWNFIELD_ID}.md` | Intent / orchestrator | Yes |
| `assumptions_file` | `/tmp/grok-brownfield-assumptions-${BROWNFIELD_ID}.md` | Orchestrator (merged) | Yes |
| `analysis_dir` | `/tmp/grok-brownfield-analysis-${BROWNFIELD_ID}/` | Specialists | Optional cleanup |
| `analysis_merged_file` | `/tmp/grok-brownfield-analysis-merged-${BROWNFIELD_ID}.md` | Orchestrator | Yes |
| `design_doc_file` | `/tmp/grok-brownfield-design-${BROWNFIELD_ID}.md` | design-doc-writer | Yes |
| `summary_file` | `/tmp/grok-brownfield-summary-${BROWNFIELD_ID}.md` | Writer | Yes |
| `design_review_file` | `/tmp/grok-brownfield-design-review-${BROWNFIELD_ID}.md` | design-doc-reviewer | Cleanup |
| `state_file` | `/tmp/grok-brownfield-state-${BROWNFIELD_ID}.json` | Orchestrator | Yes if `--execute` |
| `instructions_file` | `/tmp/grok-brownfield-instructions-${BROWNFIELD_ID}.txt` | Orchestrator | Cleanup post-execute |
| Per-specialist | `analysis_dir/{specialization}.md` | Specialist | Optional cleanup |
| Memory temp JSON | `/tmp/grok-brownfield-mem-${BROWNFIELD_ID}.json` | Orchestrator | Cleanup |
| Verify output | `/tmp/grok-brownfield-verify-${BROWNFIELD_ID}.md` | Verify subagent | Yes if Phase 6 ran |
| Per-PR exec summary | `/tmp/grok-brownfield-exec-summary-${BROWNFIELD_ID}-{pr-id}.md` | Implementer | Cleanup post-execute |
| Per-PR exec review (merged) | `/tmp/grok-brownfield-exec-review-${BROWNFIELD_ID}-{pr-id}.md` | Orchestrator (merged) | Cleanup post-execute |
| Per-PR exec review (individual) | `/tmp/grok-brownfield-exec-review-${BROWNFIELD_ID}-{pr-id}-{suffix}.md` | Reviewer | Cleanup post-execute |

**Thread paths across all rounds.** Never regenerate `BROWNFIELD_ID` mid-run.

```bash
mkdir -p /tmp/grok-brownfield-analysis-${BROWNFIELD_ID}
```

### Workspace root

After optional `cd` to project path:

```bash
git rev-parse --show-toplevel 2>/dev/null || pwd
```

Store as `workspace_root`.

### Bundled Skills Root Resolution

User-scoped brownfield **cannot** use `<dirname of this SKILL.md>/../shared/personas/`.

```
for each skill_path in skills_list:
    if "/bundled/skills/" in skill_path:
        bundled_skills_root = skill_path.split("/bundled/skills/")[0] + "/bundled/skills"
        break
if bundled_skills_root is unset:
    bundled_skills_root = "$HOME/.grok/bundled/skills"
# Validate directory exists; fail fast if not
```

### Persona Resolution

```
persona_path(name) = bundled_skills_root + "/shared/personas/" + name + ".md"
```

**Required (fail-fast):** `design-doc-writer`, `design-doc-reviewer`, `implementer`, `reviewer`, `security-auditor`. If any persona file is missing, report the absolute path and **stop** — do not proceed with empty persona instructions.

Store as `writer_persona_instructions`, `design_reviewer_persona_instructions`, `implementer_persona_instructions`, `reviewer_persona_instructions`, `security_auditor_persona_instructions`.

### Launch Conventions (all subagent spawns)

Standard `spawn_subagent` parameters unless noted:

- `subagent_type`: `"general-purpose"`
- `background`: `true` for parallel analysis specialists; `false` for writer/reviewer/intent/verify unless parallel
- `description`: `"[<tag>] <short summary>"` — bracketed role tag required
- `resume_from`: `<subagent_id>` on revision/re-review/re-run rounds only

**Persona injection:** Prepend persona instructions on initial launch when `persona_to_inject` is set. Do NOT pass a `persona` parameter. On `resume_from`, do not re-inject persona; keep bracketed tag.

**Subagent description tag map:**

| Specialist | `description` prefix |
|------------|------------------------|
| Intent | `[intent]` |
| Architecture | `[architecture]` |
| Product-Intent | `[product-intent]` |
| Code / Code-2 | `[code]` / `[code-2]` |
| Tests | `[tests]` |
| Security | `[security]` |
| Documentation | `[documentation]` |
| Writer | `[writer]` |
| Design reviewer | `[reviewer]` |
| Implementer (execute) | `[implementer]` |
| Execute reviewer | `[reviewer]` / `[tests]` / `[security]` / `[plan]` |
| Verify | `[verify]` |

**`past_issues_briefing` injection rule:** If `past_issues_briefing` is non-empty, insert it verbatim under `## Past Issue Patterns` in the prompt. If empty, omit that section entirely — never forward placeholder syntax to subagents.

### Artifact Permission & Redaction (all writers)

**Global rules for every specialist, writer, and orchestrator merge:**
- Cite secrets at `file:line` only; redact values as `[REDACTED]` in all `/tmp` artifacts
- **Scrub orchestrator-authored persistence** (`intent_brief_file`, `state_file` string fields, `instructions_file`, `user_instructions`): redact obvious credential patterns (API keys, tokens, `Bearer `, `sk-`, `AKIA`, high-entropy secrets) before write; reject paste of raw secrets in user messages when detected
- After every artifact write, run `chmod 600 <path>` (orchestrator-owned writes and instruct specialists to chmod their output files)
- User-facing messages: reference `file:line` only; never quote secret values verbatim
- After each specialist pass completes, orchestrator verifies permissions (`stat` mode) and chmod-fixes any artifact not `600` before merge

### Memory Helper

```
implement_skill_path = first skills_list entry ending in "/implement/SKILL.md"
                     ?? bundled_skills_root + "/implement/SKILL.md"
memory_helper_path = dirname(implement_skill_path) + "/scripts/memory.py"
execute_plan_skill_path = bundled_skills_root + "/execute-plan/SKILL.md"
```

Validate `memory_helper_path` exists. On missing: warn, set `past_issues_briefing = ""`, proceed.

**Memory timing (single flush per run):** `snapshot` in Phase 0 before analysis; `update` **once** — after Phase 4b when `--execute` is false; after Phase 5 completion (post Phase 6 gate) when `--execute` is true (including 0-PR skip path where Phase 6 is cancelled). Do not call `update` at both Phase 4b and post-execute.

### Memory Retrieval (Phase 0)

Run `python3 <memory_helper_path> snapshot` from `workspace_root`. Parse JSON; store `existing_patterns_snapshot`, `memory_existed_before`. Filter `count >= 2`, top 10 → `past_issues_briefing`. On failure, proceed with empty briefing.

### Orchestrator State Variables

```javascript
{
  brownfield_id, effort, execute_flag, delegate_execute_flag, max_concurrent, cleanup_deliverables,
  project_context, workspace_root,
  round_count: 0,
  analysis_round_count: 0,
  total_issues_by_severity: {},
  previous_design_review_snapshot: "",
  specialist_configs: [],
  reviewer_configs: [],              // per-PR execute reviewers (rebuilt each PR)
  ready_queue: [],
  in_progress: {},
  completed: {},
  failed: {},
  skipped: {},
  user_instructions: "",
  no_graphite_flag: false,
  auto_pr_flag: false,
  past_issues_briefing: "",
  issue_patterns: [],
  existing_patterns_snapshot: [],
  memory_existed_before: false,
  intent_subagent_id: null,
  writer_subagent_id: null,
  design_reviewer_subagent_id: null,
  bundled_skills_root: "",
  memory_helper_path: "",
  execute_plan_skill_path: "",
  plan_id: null,
  execute_plan_id: null,
  exec_summary_glob: null,
  prs_completed: 0,
  prs_failed: 0,
  prs_skipped: 0,
  dag: null,
  linearized_order: [],
  graphite_available: null,
  gh_available: null,
}
```

Report: `"Brownfield run ${BROWNFIELD_ID}, effort N, execute: true/false"`

## Phase 1: Intent Discovery

### Intent Brief Schema

Scrub user-provided text for credential patterns before writing. Write to `intent_brief_file` (chmod 600 after write):

```markdown
# Intent Brief

## Metadata
- **Run ID**: ${BROWNFIELD_ID}
- **Project**: <name or path>
- **Captured**: <ISO-8601>
- **Effort level**: <1-5>
- **Execute requested**: <true|false>

## User Goal
...

## Success Criteria
- [ ] <measurable outcome>

## Scope
### In scope
...
### Out of scope
...

## User-Visible Symptoms
...

## Constraints Stated by User
...

## Open Questions (Intent)
| ID | Question | Status |
|----|----------|--------|
| IQ-1 | ... | open|answered|

## Artifacts to Inspect
...

## Risk Tolerance
<low|medium|high> — <notes>
```

### Execution

**Option A:** Orchestrator uses AskQuestion directly when user input is thin.

**Option B:** Spawn `[intent]` subagent when conversation has rich context.

Minimum questions if incomplete: outcome goal, what works vs broken, off-limits areas, success in one sentence.

### Exit

- Open `Open Questions` → escalate via `needs-user-input`, update brief, continue
- Actionable success criteria + scope → Phase 2

Report (effort-dependent):
- Effort 1: `"Intent brief captured. Starting analysis pass 1 (Architecture)..."`
- Effort ≥2: `"Intent brief captured. Starting analysis pass 1 (Architecture + Product-Intent)..."`

## Phase 2: Assumption-Aware Analysis

### Assumptions Register Schema

```markdown
# Assumptions Register

## Summary
- **Total assumptions**: N
- **High confidence**: X
- **Medium confidence**: Y
- **Low confidence**: Z
- **Needs user confirmation**: W

## Entries

### A-001
- **Statement**: ...
- **Evidence**: file:line
- **Confidence**: high | medium | low
- **Status**: confirmed | provisional | needs_confirmation | rejected
- **Source**: [Architecture] | [Code] | [Tests] | [Product-Intent] | [Documentation] | [Security]
- **Impact if wrong**: bug | suggestion | nit | critical
- **Suggested validation**: ...
- **User question** (if needs_confirmation): ...
```

**Confidence levels:**

| Level | Meaning | Action |
|-------|---------|--------|
| `high` | Multiple independent evidence sources agree | Proceed; cite in design doc |
| `medium` | Evidence incomplete or single-source | Flag in Risks |
| `low` | Inferred from naming, comments, partial reads | If blocking → Phase 2a; else Risks |

`needs_confirmation` is a **Status** value (not a Confidence level). Blocking when `Status: needs_confirmation`.

### Blocking vs. Non-Blocking

**Blocking** if any of:
1. `Status: needs_confirmation`
2. `Confidence: low` AND `Impact if wrong` ∈ {`bug`, `critical`}
3. Referenced in Intent Brief Success Criteria with open status

**Non-blocking** low-confidence (`Impact` ∈ {`suggestion`, `nit`}): document in Phase 3 Gaps & Risks only.

### Analysis Specialist Catalog

| Specialization | Persona | Output | Pass | When |
|----------------|---------|--------|------|------|
| Architecture | prompt-only | `architecture.md` | 1 | Always |
| Product-Intent | prompt-only | `product-intent.md` | 1 | effort ≥ 2 |
| Code | `reviewer` | `code.md` | 2 | Always |
| Tests | prompt-only | `tests.md` | 2 | effort ≥ 2 OR intent signals |
| Security | `security-auditor` | `security.md` | 2 | effort ≥ 4 OR security signals |
| Documentation | prompt-only | `documentation.md` | 2 | effort ≥ 3 OR docs signals |

### Slot Algorithm (pass-2)

Build `intent_text` = lowercase concat of `project_context` + Intent Brief contents (read after Phase 1).

**Effort 1 behavior:** Pass 2 always runs Code (1 specialist). No effort-mandated optionals. Intent keyword signals may still add Tests, Security, or Documentation **in addition** — e.g. a security-focused audit at effort 1 spawns Code + Security.

```
effort_mandated = []  # dedupe on insert

if effort >= 2: effort_mandated.append("tests") if "tests" not in effort_mandated
if effort >= 3: effort_mandated.append("documentation") if "documentation" not in effort_mandated
if effort >= 4: effort_mandated.append("security") if "security" not in effort_mandated

intent_additions = []  # dedupe on insert

# Intent-based (can add below effort threshold)
if intent_text matches auth|security|user input|api key|secret|encryption|permission|token|owasp:
    intent_additions.append("security") if "security" not in intent_additions
if intent_text matches new logic|endpoint|data processing|algorithm|business rule:
    intent_additions.append("tests") if "tests" not in intent_additions
if intent_text matches readme|adr|openapi|runbook|documentation|docs:
    intent_additions.append("documentation") if "documentation" not in intent_additions

# Intent-only = triggered by keywords but not already effort-mandated
intent_only = [s for s in intent_additions if s not in effort_mandated]

PRIORITY = ["tests", "documentation", "security"]
# Always include effort-mandated; add intent-only in addition to effort-mandated (no optional_slots cap)
selected_optional = dedupe(effort_mandated + intent_only)
sort selected_optional by PRIORITY index (unknown entries last)

num_code = 2 if effort == 5 else 1
# pass-2 specialist count K = num_code + len(selected_optional) (may exceed nominal effort slots when intent expands)
```

### Building `specialist_configs` (deterministic)

```
specialist_configs = []

# Pass 1
specialist_configs.append({ pass: 1, specialization: "architecture",
  persona_to_inject: null, output_file: .../architecture.md, background: true })
if effort >= 2:
  specialist_configs.append({ pass: 1, specialization: "product-intent",
    persona_to_inject: null, output_file: .../product-intent.md, background: true })

# Pass 2 — Code (always)
specialist_configs.append({ pass: 2, specialization: "code",
  persona_to_inject: "reviewer", output_file: .../code.md, background: true })
if effort == 5:
  specialist_configs.append({ pass: 2, specialization: "code-2",
    persona_to_inject: "reviewer", output_file: .../code-2.md, background: true })

# Pass 2 — optionals from selected_optional
PERSONA_MAP = { tests: null, documentation: null, security: "security-auditor" }
for spec in selected_optional:
  specialist_configs.append({ pass: 2, specialization: spec,
    persona_to_inject: PERSONA_MAP[spec], output_file: .../{spec}.md, background: true })
```

Announce pass-1 and pass-2 compositions once, then launch.

### Wait for Completion (after each parallel pass)

Mirror `/implement` Step 2 parallel reviewers:

1. Launch all configs for the pass with `background: true`
2. For each launch, `get_command_or_subagent_output(task_id=..., block=true)`
3. Save each `subagent_id` to `specialist_configs`
4. **Required specialists (Architecture, Code):** failure → report error and stop
5. **Optional specialists (Product-Intent, Tests, Security, Documentation, code-2):** failure → warn, remove from configs, continue
6. Verify output files exist before checkpoint/merge
7. Verify each output file mode is `600`; chmod-fix if needed before checkpoint/merge

### Two-Pass Launch Order

**Pass 1** → wait → **checkpoint** → **Pass 2** → wait → **merge**

**Checkpoint after pass 1:**
1. Read `architecture.md` (and `product-intent.md` if present)
2. Write provisional `assumptions_file` (pass-1 assumptions only; assign A-### ids)
3. Write partial `analysis_merged_file`:

```markdown
## Brownfield Analysis Findings (Pass 1 — provisional)

### Architecture Summary
<excerpt from architecture.md Executive Summary>

### Product-Intent Summary
<excerpt if present>

### Pass-1 Issues
<issues tagged [Architecture] / [Product-Intent]>

### Pass-1 Assumptions
<assumption excerpts for pass-2 context>
```

Report: `"Pass 1 complete. Starting analysis pass 2 (K specialists)..."`

### Merge Analysis (after pass 2)

Orchestrator **concatenates and deduplicates** specialist outputs — **no new findings**. Only orchestrator-authored metadata: A-### assignment, Summary counts, section headers.

**Assumption ID procedure:**
1. Collect all `## Assumptions` entries from specialist files
2. Dedupe key = normalized statement + evidence
3. Assign sequential `A-001`, `A-002`, …
4. On collision, keep highest impact severity
5. Recompute Summary block counts

**Issue pattern accumulation:** After merge, extract one-line description from each open issue in specialist files; append to `issue_patterns` (dedupe exact matches).

**Final `analysis_merged_file` schema** (after pass 2):

```markdown
## Brownfield Analysis Findings

### Critical Gaps
### Bugs (confirmed or highly likely)
### Design / Architecture Issues
### Test Coverage Gaps
### Documentation Drift
### Security Findings
### Product-Intent Mismatches
### Assumptions Needing Confirmation
### Non-Blocking Low-Confidence Assumptions (document in Risks)
```

Populate each subsection from specialist issues tagged by source. **Code-2 dedup:** when merging `code.md` + `code-2.md`, dedupe on file+description; keep higher severity; tag surviving issues `[Code]` or `[Code-2]` per origin.

Steps:
1. Read all `analysis_dir/{specialization}.md` (including `code-2.md` at effort 5)
2. Merge into final `assumptions_file`
3. Write final `analysis_merged_file` per schema above with source tags
4. Evaluate blocking assumptions
5. `chmod 600` merged artifacts

Report: `"Analysis complete. N assumptions (W need confirmation)."`

## Phase 2a: Assumption Escalation

If blocking assumptions remain:

- Present each via AskQuestion (evidence + 2–4 options + "Other")
- Update `assumptions_file` → `confirmed` or `rejected`
- Increment `analysis_round_count`
- If `analysis_round_count > 3` and still blocking → escalate to narrow scope

**Re-run with `resume_from` when possible:**

Map escalated A-### ids to `Source` tags → `specialist_configs` entries.

- **Architecture/Product-Intent sources:** resume affected pass-1 specialists via `resume_from` (inject user decisions); re-checkpoint; re-run **all** pass-2 specialists (fresh or resume)
- **Pass-2 sources only:** resume pass-2 specialists whose assumptions share the escalated A-### id or matching `Source` tag; pass-1 outputs unchanged

Do not proceed to Phase 3 while blocking assumptions remain.

## Specialist Prompt Templates

### Architecture Specialist (prompt-only)

```
You are a senior systems architect performing brownfield architecture analysis.

CRITICAL: Existing code is EVIDENCE, not ground truth.

## Intent Brief
Read: <intent_brief_file>

## Your Task
- Module boundaries, layering, circular dependencies
- Data flow and trust boundaries
- Scalability bottlenecks, SPOFs
- Divergence from documented architecture
- Legacy constraints validity

## Assumption discipline
For each claim: Statement, Evidence (file:line), Confidence, Impact if wrong

## Artifact security
Cite file:line only; redact secret values as [REDACTED]. chmod 600 output file after write.

## Output
Write to: <analysis_dir>/architecture.md

## Executive Summary
## Current Architecture (as observed)
## Intent Alignment
## Issues (severity: bug|suggestion|nit)
### Issue N [Architecture] — Severity: ...
- **File**: path:line
- **Description**: ...
- **Suggestion**: ...
- **Status**: open
## Assumptions
## Recommended Investigation Order
```

Launch: `description: "[architecture] Brownfield pass-1 analysis"`, `background: true`.

### Product-Intent Specialist (prompt-only)

```
You are a product-minded engineer validating implementation vs Intent Brief.

CRITICAL: Do not rationalize existing behavior as correct because code exists.

## Intent Brief
Read: <intent_brief_file>

## Your Task
- Map user-visible flows to code paths
- Contradictions vs Intent Brief / user expectations
- Feature flags, dead paths, half-implemented flows
- UX-adjacent backend issues

## Artifact security
Redact secrets; chmod 600 output.

## Output
Write to: <analysis_dir>/product-intent.md
Same Issue + Assumptions structure. Source tag: [Product-Intent]
```

Launch: `description: "[product-intent] Product-intent validation"`, `background: true`.

### Documentation Specialist (prompt-only, pass 2)

```
You are auditing documentation fidelity. Pass 2 — pass-1 analysis complete.

## Intent Brief: <intent_brief_file>
## Pass-1 Context
Read: <analysis_dir>/architecture.md
Read if present: <analysis_dir>/product-intent.md
Read: <assumptions_file>

## Your Task
- README, ADRs, inline docs, OpenAPI vs code
- Drift: missing | stale | misleading | accurate
- Operational docs gaps

## Output
Write to: <analysis_dir>/documentation.md
Source tag: [Documentation]. chmod 600 after write.
```

Launch: `description: "[documentation] Documentation fidelity audit"`, `background: true`.

### Code Specialist (pass 2)

Inject `reviewer_persona_instructions`. Include `## Past Issue Patterns` block only when `past_issues_briefing` is non-empty.

```
<reviewer_persona_instructions>

---

Brownfield CODE analysis — existing codebase (not a diff). Pass 2.

## Intent Brief: <intent_brief_file>
## Pass-1 Context
Read: <analysis_dir>/architecture.md
Read if present: <analysis_dir>/product-intent.md
Read: <assumptions_file>

## Scope
Prioritize Intent Brief + Architecture findings.

## Assumption discipline
Record inferences with confidence; challenge pass-1 assumptions if code contradicts.

## Output
Write to: <analysis_dir>/code.md
### Issue N [Code] — Severity: bug|suggestion|nit
- **File**: path:line
- **Description**: ...
- **Suggestion**: ...
- **Status**: open
## Assumptions
chmod 600 after write.
```

Launch: `description: "[code] Brownfield code analysis"`, `background: true`.

### Code-2 Specialist (pass 2, effort 5 only)

Same as Code Specialist with independent review pass. Inject `reviewer_persona_instructions`. Include `## Past Issue Patterns` only when `past_issues_briefing` is non-empty.

Source tag: `[Code-2]`. Output: `<analysis_dir>/code-2.md`. Launch: `description: "[code-2] Brownfield code analysis (pass 2b)"`, `background: true`.

### Tests Specialist (prompt-only, pass 2)

```
You are a thorough test engineer analyzing a brownfield codebase.

CRITICAL: Existing tests are EVIDENCE, not proof of adequate coverage. Green CI does not mean intent is validated.

## Intent Brief: <intent_brief_file>
## Pass-1 Context
Read: <analysis_dir>/architecture.md
Read if present: <analysis_dir>/product-intent.md
Read: <assumptions_file>

Include `## Past Issue Patterns` block only when `past_issues_briefing` is non-empty.

## Your Task
- Coverage vs intent success criteria and critical paths
- Edge cases, error paths, boundary conditions
- Assertion quality (not just "doesn't throw")
- Integration/e2e for user-visible flows
- Mocking appropriateness
- Flaky tests, brittle snapshots, missing negative-path tests
- Locate test infrastructure: package.json scripts, pytest.ini, Cargo.toml, CI workflows
- Undocumented or failing test commands; missing coverage thresholds
- Challenge pass-1 assumptions when test evidence contradicts them

## Output
Write to: <analysis_dir>/tests.md

## Issues
### Issue N [Tests] — Severity: bug|suggestion|nit
- **File**: path:line
- **Description**: ...
- **Suggestion**: ...
- **Status**: open
## Assumptions
chmod 600 after write.
```

Launch: `description: "[tests] Test coverage analysis"`, `background: true`.

### Security Specialist (pass 2)

Inject `security_auditor_persona_instructions`.

```
<security_auditor_persona_instructions>

---

IGNORE persona severity labels (critical/high/medium/low) and Finding format.
Use ONLY bug/suggestion/nit and Issue format below.

Analyze brownfield codebase for security issues. Pass 2.

## Intent Brief: <intent_brief_file>
## Pass-1 Context
Read: <analysis_dir>/architecture.md
Read if present: <analysis_dir>/product-intent.md
Read: <assumptions_file>

Include `## Past Issue Patterns` block only when `past_issues_briefing` is non-empty.

Focus: input validation, authz, injection, secrets/PII, crypto, rate limiting, OWASP Top 10.

IMPORTANT severity mapping:
- bug: exploitable vulnerabilities
- suggestion: defense-in-depth
- nit: informational

Never copy credential values into security.md — file:line + [REDACTED] only.

## Output
Write to: <analysis_dir>/security.md
### Issue N [Security] — Severity: bug|suggestion|nit
- **File**: path:line
- **Description**: ...
- **Suggestion**: ...
- **Status**: open
## Assumptions
chmod 600 after write.
```

Launch: `description: "[security] Security audit"`, `background: true`.

### Verify Specialist (prompt-only)

```
You are validating brownfield improvements met original intent.

## Inputs
- Intent Brief: <intent_brief_file>
- Design doc: <design_doc_file>
- Execute summaries: <exec_summary_glob>
- Execute plan ID: <execute_plan_id> (delegated path only)
- Execute plan state: /tmp/grok-exec-plan-<execute_plan_id>.json (if delegated)
- Assumptions Register: <assumptions_file>
- Pre-implementation tests review: <analysis_dir>/tests.md (if exists)
- Merged analysis: <analysis_merged_file>
- PR completion stats: completed=<prs_completed>, failed=<prs_failed>, skipped=<prs_skipped>

## Task
1. Run documented test command from execute summaries if safe; cite exit codes
2. Map each Success Criterion → met | partially met | not met | not verified
3. Diff open [Tests] issues from tests.md against post-execute evidence
4. Flag regressions and unresolved assumptions
5. Note PRs not verified due to failed/skipped status
6. Classify blockers as bug/suggestion; recommend /implement for scoped fixes or new /brownfield for broad re-audit
7. v1: no verify review loop — informational only

## Output
Write to: /tmp/grok-brownfield-verify-${BROWNFIELD_ID}.md

## Success Criteria Verification
| Criterion | Status | Evidence |
|-----------|--------|----------|
| ... | met/partial/not met/not verified | ... |

## Regressions
### Issue N — Severity: bug|suggestion
- **Description**: ...
- **Suggestion**: ...

## Follow-up PRs
...

chmod 600 after write.
```

## Phase 3: Consolidated Design Document

Launch design-doc-writer:

`spawn_subagent` parameters:
- `subagent_type`: `"general-purpose"`
- `description`: `"[writer] Write brownfield design doc"`

```
<writer_persona_instructions>

---

Write a BROWNFIELD improvement design document.

## Inputs
- Intent Brief: <intent_brief_file>
- Merged analysis: <analysis_merged_file>
- Assumptions Register: <assumptions_file>
- Project context: <project_context>

## Required sections
- Current State Assessment
- Validated Findings (grouped by severity)
- Assumptions & Confidence (A-### table)
- Gaps & Risks
- Improvement Strategy
- Key Decisions (MANDATORY)
- PR Plan (MANDATORY, ### PR N: headings)
- Open Questions

Include Mermaid diagrams for current vs. proposed architecture where helpful.
The PR Plan must be realistic for /execute-plan parsing (### PR N: headings).

Redact secrets in design doc. Write to: <design_doc_file> and <summary_file>
chmod 600 both files.
```

Wait for completion. If subagent fails, report error and stop. Save `writer_subagent_id`.

Report: `"Design document drafted. Starting design review..."`

## Phase 4: Design Review Loop

**Severity taxonomy:** Analysis findings use `bug/suggestion/nit` in merged analysis. Design-review issues use `critical/major/minor/nit` (per `/design`). Do not mix taxonomies in `design_review_file`.

Normative reference: `/design` Steps 2–5.

### Step 4.1: Review

`spawn_subagent`:
- `subagent_type`: `"general-purpose"`
- `description`: `"[reviewer] Review brownfield design doc"`

```
<design_reviewer_persona_instructions>

---

Review brownfield improvement design document.

Files: <design_doc_file>, <summary_file>, <assumptions_file>, <analysis_merged_file>
Write review to: <design_review_file>
Severity: critical|major|minor|nit. Every issue Status: open.

Pay special attention to: assumptions escalation, evidence citations, PR Plan ordering, do-no-harm rollout, Key Decisions.

## Artifact security
Redact secret values as [REDACTED] in review_file; cite file:line only. chmod 600 review_file after write.
```

If fails → stop. Save `design_reviewer_subagent_id`. Increment `round_count`.

### Step 4.2: Check Exit Condition

Read `design_review_file`. Count open and needs-user-input.

**Decision order (strict):**
1. **0 open AND 0 needs-user-input** → Phase 4b
2. **Any needs-user-input** → Step 4.2a
3. **Stalemate** (wontfix re-opened) → Step 4.2a
4. **Any open** → Step 4.3

**Stalemate detection:** Compare against `previous_design_review_snapshot` **after writer revision** (snapshot taken post-Step 4.3, not pre-revise). If wontfix issue re-opened as open → stalemate.

Accumulate severities into `total_issues_by_severity`. Extract one-line descriptions from open issues → append to `issue_patterns` (dedupe).

### Step 4.2a: Escalate to User

For `needs-user-input` and stalemate issues:
- Frame question in plain language for non-technical users
- Include reviewer position and writer position (stalemates)
- Provide selectable options + "Other"
- Include design-doc context

After user responds: resume writer (Step 4.3) with user decisions as **final** — incorporate without debate, set issues to `addressed`.

### Step 4.3: Revise

`spawn_subagent`:
- `resume_from`: `<writer_subagent_id>`
- `description`: `"[writer] Revise design doc"`

```
The review_file is at: <design_review_file>
Address ALL Status: open issues. Update design_doc_file and review_file (open → addressed + Response).
May set wontfix with justification or needs-user-input.
Append Revision Summary to review_file.
```

If fails → stop. Update `writer_subagent_id`.

**After Step 4.3 completes:** update `previous_design_review_snapshot` from current `design_review_file`.

### Step 4.4: Re-review

`spawn_subagent`:
- `resume_from`: `<design_reviewer_subagent_id>`
- `description`: `"[reviewer] Re-review design doc"`

Rewrite `design_review_file`. Go back to Step 4.2 until 0 open.

Report on pass: `"Design review passed with 0 issues. Finalizing Key Decisions and PR Plan..."`

## Phase 4b: Summarize and Ask Open Questions

### 4b.1: Extract Key Decisions

Present concise summary from `design_doc_file` § Key Decisions.

### 4b.2: Ask Open Questions

For unresolved Open Questions: plain-language AskQuestion with options + "Other". If answered: resume writer once, skip re-review.

### 4b.3: Present PR Plan

Read and present `## PR Plan`.

- **If `execute_flag` is true:** Present PR Plan summary informatively; **do not re-ask** whether to execute — proceed directly to 4b.4 and Phase 5.
- **If `execute_flag` is false:** Present PR Plan and offer paths: take design doc only, or re-invoke `/brownfield --execute --effort <N> <project_context>`.

If user opts in at 4b.3 without `--execute` flag: instruct exact re-invocation command (cannot start Phase 5 in same run without `execute_flag`).

### 4b.4: Prepare Execute Handoff + State File (if `--execute`)

**Order (required):**

1. **Build `instructions_file`** — read `intent_brief_file` + `assumptions_file`; extract Success Criteria + confirmed assumptions; scrub secrets; write to `/tmp/grok-brownfield-instructions-${BROWNFIELD_ID}.txt`; `chmod 600`. On resume rebuild: fail fast if source files missing.
2. **Write `state_file`** with current orchestrator values (not defaults). Set `phase` by path:
   - **Inline (default):** `phase: "execute_inline"`, `exec_summary_glob: "/tmp/grok-brownfield-exec-summary-${BROWNFIELD_ID}-*.md"`
   - **Delegation (`--delegate-execute`):** `phase: "execute_pending"`, `exec_summary_glob: null` until PLAN_ID known

```json
{
  "brownfield_id": "<BROWNFIELD_ID>",
  "plan_id": "<BROWNFIELD_ID>",
  "execute_plan_id": null,
  "exec_summary_glob": "<inline glob or null>",
  "phase": "execute_inline|execute_pending",
  "effort": "<effort>",
  "delegate_execute": "<delegate_execute_flag>",
  "max_concurrent": "<max_concurrent>",
  "no_graphite_flag": "<no_graphite_flag>",
  "auto_pr_flag": "<auto_pr_flag>",
  "project_context": "<scrubbed project_context>",
  "workspace_root": "<workspace_root>",
  "intent_brief_file": "<intent_brief_file>",
  "assumptions_file": "<assumptions_file>",
  "design_doc_file": "<design_doc_file>",
  "analysis_merged_file": "<analysis_merged_file>",
  "design_doc_path": "<design_doc_file>",
  "instructions_file": "<instructions_file>",
  "status": "initializing",
  "created_at": "<ISO 8601>",
  "linearized_order": [],
  "dag": { "nodes": [] },
  "stack_assembly_started": false,
  "stack_assembly_progress": [],
  "graphite_stack_submitted": false,
  "graphite_available": null,
  "gh_available": null,
  "pr_urls": [],
  "pr_create_commands": [],
  "user_instructions": "<scrubbed inline text from instructions_file>",
  "analysis_round_count": "<analysis_round_count>",
  "round_count": "<round_count>",
  "prs_completed": 0,
  "prs_failed": 0,
  "prs_skipped": 0
}
```

Per-PR `dag.nodes[]` include `worktree_cleaned: false` (and all execute-plan node fields: `commit_sha`, `worktree_path`, `review_rounds`, `reviewer_configs`, etc.) as execution progresses.

3. `chmod 600` state_file

If `--execute` is false → skip state file; proceed to memory flush + Final Report.

## Phase 5: Execution (`--execute`)

When `execute_flag` is true and Phase 4b completes.

**Path selection (first action in Phase 5):**
- If `delegate_execute_flag` → jump to **Delegated Execution Path** below.
- Else → **Inline Execution Path** (primary). Read `instructions_file` into `user_instructions`; set `phase: "execute_inline"` and persist `state_file` if not already set.

**Path summary:**
- **Primary (default):** Inline execute — worktree-isolated implementers, effort-scaled per-PR reviewers, stack assembly. `phase: execute_inline`.
- **Fallback:** `--delegate-execute` → nested `/execute-plan` at effort 1. `phase: execute_delegated`.

You are the **single point of control** for all git and stack-tooling during inline execute. Subagents implement in worktrees; you create branches, collect commits, and submit/push stacks.

Report: `"Executing PR Plan: M PRs, concurrency C, effort N, mode: inline|delegated"`

### Inline Execution Path (PRIMARY)

Substitute `PLAN_ID = BROWNFIELD_ID` and `design_doc_path = design_doc_file` throughout. Artifact prefix: `/tmp/grok-brownfield-exec-{summary|review}-*`. Branch prefix: `brownfield/<BROWNFIELD_ID>-<pr-number>-<slug>`.

#### Subagent Worktree Protocol

The orchestrator interacts with subagent worktrees through git commands that work uniformly across environments. Do not branch on host or worktree mechanism — this protocol is the only contract.

**Rule 1 — fetch without a destination refspec.** When you need subagent commits in the main repo:

```bash
git fetch "<worktree_path>" HEAD --no-tags
```

Never add `:refs/heads/<pr.branch>` and never pass `--force`. Always double-quote `"<worktree_path>"` in shell.

**Rule 2 — `pr.commit_sha` is authoritative.** After every fetch:

```bash
pr.commit_sha = $(git -C "<worktree_path>" rev-parse HEAD)
git cat-file -t "<pr.commit_sha>"   # must print "commit"
```

Downstream steps key off `commit_sha`, never `refs/heads/<pr.branch>` in the main repo.

**Worktree path validation (on record and resume):** When persisting or restoring `pr.worktree_path`, validate: absolute path, no `..`, no shell metacharacters, directory exists, is a git worktree under grok worktree root. Reject invalid paths before interpolation into shell.

**Rule 3 — tear down worktree before mutating branch ref.** Immediately before stack assembly mutates `refs/heads/<pr.branch>`:

```bash
if [ -n "<pr.worktree_path>" ] && [ -d "<pr.worktree_path>" ]; then
  grok worktree rm --force "<pr.worktree_path>"
fi
```

Idempotent — safe when worktree already gone or never created.

#### Two Assembly Modes

Recorded in `state_file` as `graphite_available` (probed in Step 0.5):

- **Graphite mode** (`graphite_available == true`): per-PR `gt create` + cherry-pick; single `gt submit --stack` epilogue (Step 8a).
- **Plain-git mode** (default when `gt` missing): plain git branch chain + `git push --force-with-lease`. PRs not auto-created unless `gh` available and orchestrator chooses `gh pr create` (optional; compare URLs printed otherwise).

#### Execute Todo Scaffold

Each DAG node → todo `pr-<node-id>` with sub-ids: `pr-<n>:branch-prep`, `pr-<n>:execute`, `pr-<n>:review`, `pr-<n>:merge-ready`. Terminal: all `pr-<n>:merge-ready` completed. Reseed from `state_file` after compaction.

#### Step 0.5: Tool Detection (Graphite & gh)

Probe once (safe `if ... then ... else ... fi` form):

```bash
if command -v gt >/dev/null 2>&1; then echo "yes"; else echo "no"; fi
if command -v gh >/dev/null 2>&1; then echo "yes"; else echo "no"; fi
```

When `gt` probe returns `yes`, additionally verify `gt --help 2>/dev/null | grep -qi graphite`; treat unrecognized output as `no`.

- `gh_available = (gh probe == "yes")`
- `graphite_available = (gt verified AND no_graphite_flag == false)`

Rewrite `state_file` with updated values. Report Graphite or plain-git mode (mirror execute-plan messages). Persist after probe.

#### Step 1: Parse PR Plan DAG

Read `design_doc_file`. Extract `## PR Plan`; parse each `### PR N:` into `PRNode`:

```
PRNode {
  id, title, slug, description, files[], dependencies[], level,
  status: "pending", branch, subagent_id, worktree_path,
  base_sha, commit_sha, error, reviewer_subagent_ids: {},
  review_rounds: 0, reviewer_configs: [], started_at, completed_at,
  worktree_cleaned: false
}
```

Slug rules (same as execute-plan): lowercase, hyphens, `[a-z0-9-]` only, truncate 50, strip `.lock`, fallback `"unnamed"`. Validate DAG: resolve dependencies, detect cycles, unique ids. Store in `dag.nodes`. Persist `state_file`.

Report: `"Parsed PR Plan: <N> PRs found."`

#### Step 2: DAG Processing and Linearization

Assign levels: `level = 0` if no deps else `max(level(dep)) + 1`.

Linearize (deterministic — sort by numeric PR number within level, not lexicographic id):

```
def linearize(dag):
    nodes_by_level = group_by(dag.nodes, key=n.level)
    result = []
    for level in sorted(nodes_by_level.keys()):
        for node in sorted(nodes_by_level[level], key=lambda n: int(n.id.split('-')[1])):
            result.append(node)
    return result
```

Branch name: `brownfield/<BROWNFIELD_ID>-<pr-number>-<slug>`. Store `linearized_order`; persist `state_file`.

Report linearized order, max parallelism, level count.

#### Step 3: Branch Preparation

```bash
git fetch origin main
```

**Level 0:** `git branch <pr.branch> origin/main`; `pr.base_sha = $(git rev-parse <pr.branch>)`

**Single dependency (JIT when dep completes):** `git branch <pr.branch> <dep.commit_sha>`

**Multiple dependencies (diamond):**

```bash
git branch "<pr.branch>" "<first-dep.commit_sha>"

TEMP_WT=$(mktemp -d)
git worktree add "$TEMP_WT" "<pr.branch>"
git -C "$TEMP_WT" merge "<second-dep.commit_sha>" --no-edit
git worktree remove "$TEMP_WT"

pr.base_sha = $(git rev-parse "<pr.branch>")
```

Key off `dep.commit_sha`, never branch name. **Do NOT switch orchestrator checked-out branch** — use `git branch` without checkout.

Set status `"branch_created"`; persist `state_file`.

Report: `"Created branches for <N> level-0 PRs. Starting implementation..."`

#### Step 4: Execution Loop

Re-run `umask 077` before each implementer/reviewer batch. After Step 5b merge, chmod-fix exec review artifacts.

Ready-queue loop (mirror execute-plan):

```
ready_queue = PRs with status "branch_created" and deps completed
while ready_queue or in_progress:
    launch up to max_concurrent implementers
    wait_commands_or_subagents(mode="wait_any", timeout_ms=600000)
    on timeout (>15min): kill, mark failed, cascade_skip
    on completion: process_completion → review_pr
    enqueue newly-ready PRs (create branches JIT)
```

##### Step 4a: Launch Implementer

After worktree creation, push branch into worktree before implementer checks out:

```bash
git push "<worktree_path>" refs/heads/<pr.branch>:refs/heads/<pr.branch>
```

`spawn_subagent`: `subagent_type: "general-purpose"`, `isolation: "worktree"`, `background: true`, `description: "[implementer] <pr.id>: <pr.title>"`

**Prepend `implementer_persona_instructions`.** Prompt:

```
<implementer_persona_instructions>

---

You are implementing a single PR as part of a brownfield improvement plan.

## Your PR
- Title: <pr.title>
- Description: <pr.description>
- Files to modify: <pr.files joined by comma>
- Branch: <pr.branch>

## Context from Design Document
<relevant sections from design_doc_file for this PR's scope>

<if past_issues_briefing is non-empty, include verbatim:>
<past_issues_briefing>
Be proactive about avoiding these patterns in your implementation.
<end if>

<if user_instructions is non-empty, include verbatim:>
## User Instructions
<user_instructions>
These instructions apply to all work in this plan. Follow them strictly.
<end if>

## Artifact security
Cite secrets at file:line only; redact values as [REDACTED]. chmod 600 summary after write.

## Instructions
1. git checkout <pr.branch>
2. Implement the changes described above.
3. Verify compile/basic checks (cargo check, tsc --noEmit, pytest, etc.).
4. Commit all changes with a descriptive message.
5. Write implementation summary to: /tmp/grok-brownfield-exec-summary-${BROWNFIELD_ID}-<pr.id>.md
   Include: files changed, key decisions, deviations from plan.
```

Set status `"implementing"`; persist `state_file`.

##### Step 4b: Process Completion

On success: record `subagent_id`, `worktree_path` (validate before persist per Worktree Protocol); `git -C "<worktree_path>" rev-parse HEAD` → `commit_sha`; `git fetch "<worktree_path>" HEAD --no-tags`; `git cat-file -t "<commit_sha>"`. Status → `"reviewing"`.

On failure: status `"failed"`, cascade_skip (Step 6). Persist after each transition.

#### Step 5: Per-PR Review (Effort-Scaled)

Build `reviewer_configs` **per PR** using `/implement` Specialization Selection with `description = pr.title + " " + pr.description + design doc excerpt`. Use brownfield `effort` (1–5), **not** hardcoded 1.

**Effort → reviewer slots (same as `/implement`):**

| Effort | Reviewers | Composition |
|--------|-----------|-------------|
| 1 | 1 | General `reviewer` |
| 2 | 2 | General + specialist OR 2 generals |
| 3 | 3 | Up to 2 generals + specialists |
| 4 | 5 | 3 generals + tests + security (typical) |
| 5 | 6 | 3 generals + tests + security + plan alignment (when matched) |

**Decision algorithm (per PR)** — port `/implement` Specialization Selection Step 2:

```
description = pr.title + " " + pr.description + " " + <design doc excerpt for this PR>

if effort <= 3: total_slots = effort
elif effort == 4: total_slots = 5
else: total_slots = 6

matched_specialists = []

if description mentions auth, security, user input, API keys,
   secrets, encryption, permissions, tokens, or OWASP:
    matched_specialists.append("security")

if description references design doc, plan, spec, RFC, PR Plan,
   or linked document:
    matched_specialists.append("plan_alignment")

if description involves new logic, endpoints, data processing,
   algorithms, or business rules:
    matched_specialists.append("tests")

specialists = matched_specialists[:total_slots - 1]
num_generals = total_slots - len(specialists)
```

**Building reviewer_configs (per PR):**

```
reviewer_configs = []
for i in 1..num_generals:
    tag = "general" if i == 1 else f"general-{i}"
    reviewer_configs.append({
      subagent_id: null,
      persona_to_inject: "reviewer",
      specialization: tag,
      review_file: effort == 1
        ? "/tmp/grok-brownfield-exec-review-${BROWNFIELD_ID}-<pr.id>.md"
        : f"/tmp/grok-brownfield-exec-review-${BROWNFIELD_ID}-<pr.id>-{tag}.md"
    })
suffix_map = {tests: "tests", security: "security", plan_alignment: "plan"}
for specialist in specialists:
    reviewer_configs.append({
      subagent_id: null,
      persona_to_inject: specialist == "security" ? "security-auditor" : null,
      specialization: specialist,
      review_file: f"/tmp/grok-brownfield-exec-review-${BROWNFIELD_ID}-<pr.id>-{suffix_map[specialist]}.md"
    })
```

Announce once per PR: `"<pr.id> review: effort <N>, <total_slots> reviewers (<composition>)"`

Merged review file: `/tmp/grok-brownfield-exec-review-${BROWNFIELD_ID}-<pr.id>.md`

##### Step 5a: Launch Reviewer(s)

Read exec summary at `/tmp/grok-brownfield-exec-summary-${BROWNFIELD_ID}-<pr.id>.md`; derive `reviewer_focus_areas` (2–3 items).

**Effort 1:** Single reviewer with `cwd: "<pr.worktree_path>"`, prepend `reviewer_persona_instructions`. Prompt:

```
<reviewer_persona_instructions>

---

Review the changes made for <pr.id>: <pr.title>.

The implementation summary is at: /tmp/grok-brownfield-exec-summary-${BROWNFIELD_ID}-<pr.id>.md
Review all modified files in the worktree (cwd).

<if past_issues_briefing is non-empty, include verbatim:>
<past_issues_briefing>
<end if>

<if user_instructions is non-empty, include verbatim:>
## User Instructions
<user_instructions>
<end if>

<if reviewer_focus_areas is non-empty:>
## Additional focus areas (from implementation summary)
<reviewer_focus_areas>
<end if>

## Artifact security
Redact secrets as [REDACTED]; chmod 600 review file after write.

Write review to: /tmp/grok-brownfield-exec-review-${BROWNFIELD_ID}-<pr.id>.md
### Issue N — Severity: bug|suggestion|nit
- **File**: path:line
- **Description**: ...
- **Suggestion**: ...
- **Status**: open
```

**Effort ≥ 2:** Launch all reviewers in parallel (`background: true`) with `cwd: "<pr.worktree_path>"`. Use the inlined Specialized Review Prompts below (brownfield exec artifact paths; do not cross-lookup `/implement`).

Exec summary path: `/tmp/grok-brownfield-exec-summary-${BROWNFIELD_ID}-<pr.id>.md`

**General Reviewer** (`persona_to_inject: "reviewer"`):

```
<reviewer_persona_instructions>

---

Review the changes made for <pr.id>: <pr.title>.

The implementation summary is at: /tmp/grok-brownfield-exec-summary-${BROWNFIELD_ID}-<pr.id>.md
Review all modified files in the worktree (cwd).

<if past_issues_briefing is non-empty, include verbatim:>
<past_issues_briefing>
<end if>

<if user_instructions is non-empty, include verbatim:>
## User Instructions
<user_instructions>
<end if>

<if reviewer_focus_areas is non-empty:>
## Additional focus areas (from implementation summary)
<reviewer_focus_areas>
<end if>

## Artifact security
Redact secrets as [REDACTED]; chmod 600 review file after write.

Write review to: <reviewer_configs[i].review_file>
### Issue N — Severity: bug|suggestion|nit
- **File**: path:line
- **Description**: ...
- **Suggestion**: ...
- **Status**: open
```

**Tests Specialist** (prompt-only; no persona):

```
You are a thorough test engineer reviewing code changes for test coverage and quality.

Review the changes made for <pr.id>: <pr.title>, focusing specifically on test coverage and quality.

The implementation summary is at: /tmp/grok-brownfield-exec-summary-${BROWNFIELD_ID}-<pr.id>.md
Review all modified files in the worktree (cwd).

<if past_issues_briefing is non-empty, include verbatim:>
<past_issues_briefing>
<end if>

<if user_instructions is non-empty, include verbatim:>
## User Instructions
<user_instructions>
<end if>

<if reviewer_focus_areas is non-empty:>
## Additional focus areas (from implementation summary)
<reviewer_focus_areas>
<end if>

Your review should focus on:
- Whether new/changed code has adequate test coverage
- Whether tests cover edge cases, error paths, and boundary conditions
- Whether test assertions are specific enough (not just "doesn't throw")
- Whether tests are maintainable and not overly coupled to implementation details
- Whether integration tests exist for new endpoints or interfaces
- Whether mocking is used appropriately (not over-mocking)

Do NOT review for general code style, naming, or architecture — another reviewer handles that.

## Artifact security
Redact secrets as [REDACTED]; chmod 600 review file after write.

Write review to: <reviewer_configs[i].review_file>
### Issue N — Severity: bug|suggestion|nit
- **File**: path:line
- **Description**: ...
- **Suggestion**: ...
- **Status**: open
```

**Security Specialist** (`persona_to_inject: "security-auditor"`):

```
<security_auditor_persona_instructions>

---

Review the changes made for <pr.id>: <pr.title>, focusing specifically on security.

The implementation summary is at: /tmp/grok-brownfield-exec-summary-${BROWNFIELD_ID}-<pr.id>.md
Review all modified files in the worktree (cwd).

<if past_issues_briefing is non-empty, include verbatim:>
<past_issues_briefing>
<end if>

<if user_instructions is non-empty, include verbatim:>
## User Instructions
<user_instructions>
<end if>

<if reviewer_focus_areas is non-empty:>
## Additional focus areas (from implementation summary)
<reviewer_focus_areas>
<end if>

Your review should focus on:
- Input validation and sanitization
- Authentication and authorization checks
- Injection vulnerabilities (SQL, command, path traversal)
- Sensitive data handling (secrets, PII, tokens in logs)
- Cryptographic correctness
- Rate limiting and abuse prevention
- OWASP Top 10 patterns

IMPORTANT: Use severity labels bug/suggestion/nit (not security-standard severities):
- bug: critical/high (exploitable vulnerabilities)
- suggestion: medium (defense-in-depth)
- nit: low/informational (best-practice)

Only flag real, exploitable issues — not theoretical concerns.
Do NOT review for general code style or test coverage — other reviewers handle that.

## Artifact security
Redact secrets as [REDACTED]; chmod 600 review file after write.

Write review to: <reviewer_configs[i].review_file>
### Issue N — Severity: bug|suggestion|nit
- **File**: path:line
- **Description**: ...
- **Suggestion**: ...
- **Status**: open
```

**Plan Alignment Specialist** (prompt-only; no persona):

```
You are a technical lead reviewing whether an implementation correctly follows its design plan.

Review the changes made for <pr.id>: <pr.title>, focusing on whether the implementation matches the plan/design.

The implementation summary is at: /tmp/grok-brownfield-exec-summary-${BROWNFIELD_ID}-<pr.id>.md
Review all modified files in the worktree (cwd).

Read the design document in full before starting: <design_doc_file>

<if past_issues_briefing is non-empty, include verbatim:>
<past_issues_briefing>
<end if>

<if user_instructions is non-empty, include verbatim:>
## User Instructions
<user_instructions>
<end if>

<if reviewer_focus_areas is non-empty:>
## Additional focus areas (from implementation summary)
<reviewer_focus_areas>
<end if>

Your review should focus on:
- Whether all requirements from the plan are addressed for this PR's scope
- Whether the implementation deviates from the planned approach
- Whether any scope creep has occurred (implementing things not in the plan)
- Whether any planned items for this PR are missing
- Whether interfaces match what was specified

Do NOT review for code style, tests, or security — other reviewers handle that.

## Artifact security
Redact secrets as [REDACTED]; chmod 600 review file after write.

Write review to: <reviewer_configs[i].review_file>
### Issue N — Severity: bug|suggestion|nit
- **File**: path:line
- **Description**: ...
- **Suggestion**: ...
- **Status**: open
```

Wait via `get_command_or_subagent_output(block=true)` for each. Save `subagent_id` to `reviewer_configs[].subagent_id`. General failure → stop PR; specialist failure → warn, remove from configs, continue.

##### Step 5b: Merge & Check Results

**Effort 1:** Read merged review file; count `Status: open`.

**Effort ≥ 2:** Read individual files; merge into `/tmp/grok-brownfield-exec-review-${BROWNFIELD_ID}-<pr.id>.md` with source tags `[General]`, `[General-2]`, `[Tests]`, `[Security]`, `[Plan]`. Dedupe obvious duplicates; when in doubt keep both.

Extract one-line descriptions → `issue_patterns` (dedupe). Add severities to `total_issues_by_severity`. Increment `pr.review_rounds`. `chmod 600` review files.

- **0 open issues:** status `"completed"`, `completed_at`; return to Step 4 loop.
- **Any open:** Step 5c fix cycle (no iteration cap — all severities must reach 0).

##### Step 5c: Fix Cycle

Resume implementer (`resume_from: pr.subagent_id`). Prompt: read merged review file, fix all `Status: open`, update to `fixed`/`wontfix`, commit, include `user_instructions`.

Re-fetch commits (Rule 1–2). Resume reviewer(s) (`resume_from` per `reviewer_configs[].subagent_id`; **update all `reviewer_configs[].subagent_id` after each resume round**). On resume failure: fresh launch with full Step 5a prompt + `cwd: "<pr.worktree_path>"`; update ids. Re-merge if effort ≥ 2.

**Stalemate:** wontfix re-opened → escalate to user via AskQuestion; user decision is final.

Persist `state_file` after each round.

#### Step 6: Failure Handling

On PR failure: mark `"failed"` with error; `cascade_skip` all transitive dependents (`status: "skipped"`, `error: "Skipped: dependency <id> failed"`). Independent PRs continue. Persist `state_file`.

#### Step 7: Resumption (`--resume` with `phase: execute_inline` or legacy `execute`)

1. Read `state_file` at `/tmp/grok-brownfield-state-${BROWNFIELD_ID}.json`
2. Restore: `design_doc_file`, `effort`, `max_concurrent`, `dag`, `linearized_order`, `user_instructions`, `no_graphite_flag`, `auto_pr_flag`, `graphite_available`, `gh_available`, `pr_urls`, `pr_create_commands`, `prs_completed`, `prs_failed`, `prs_skipped`, brownfield artifact paths. Defaults for missing fields: `no_graphite_flag: false`, `auto_pr_flag: false`, `pr_create_commands: []`, `stack_assembly_progress: []`. If `graphite_available` or `gh_available` is null, re-run Step 0.5 probe.
3. Re-validate each `dag` node slug/branch and `worktree_path` (see Invocation resume validation)
4. Per PR status:
   - `completed` → skip
   - `failed` → if `worktree_path` set and `worktree_cleaned` is false, `grok worktree rm --force "<worktree_path>"`; reset to `"pending"` (clear error, subagent_id, reviewer ids in `reviewer_configs`, worktree_path, base_sha, commit_sha, review_rounds, worktree_cleaned)
   - `skipped` → re-evaluate if deps now completed
   - `implementing`/`reviewing` → cleanup worktree (`worktree_cleaned` guard); reset to `"pending"`; clear reviewer ids in `reviewer_configs`
   - `pending`/`branch_created` → keep
5. If `stack_assembly_started` && !`graphite_stack_submitted`:
   - **Graphite mode:** `gt ls`, delete partial branches with `gt delete`, reset to main
   - **Plain-git mode:**
     ```bash
     git cherry-pick --abort 2>/dev/null || true
     git merge --abort 2>/dev/null || true
     git rebase --abort 2>/dev/null || true
     git fetch origin main
     git checkout -f main
     git reset --hard origin/main
     while IFS= read -r branch; do git branch -D "$branch"; done < <(git for-each-ref --format='%(refname:short)' "refs/heads/brownfield/<BROWNFIELD_ID>-*")
     ```
   - Set `stack_assembly_started = false`; clear `stack_assembly_progress`
6. Re-read `design_doc_file`; resume from Step 3 + Step 4

Report: `"Resuming brownfield execute ${BROWNFIELD_ID}. <N> completed, <M> to retry, <K> skipped."`

#### Step 8: Stack Assembly

When all PRs are `completed`, `failed`, or `skipped` AND ≥1 completed:

Set `stack_assembly_started = true`; persist.

Branch on `graphite_available`:
- `true` → **Step 8a (Graphite mode)**
- `false` → **Step 8a (plain-git mode)**

##### Step 8a (Graphite mode): Build the Stack

One-time prologue at loop start:

```bash
git checkout main
git pull origin main
```

Per PR (linearized order, skip failed/skipped):

```bash
# Rule 3 — free branch name
if [ -n "<pr.worktree_path>" ] && [ -d "<pr.worktree_path>" ]; then
  grok worktree rm --force "<pr.worktree_path>"
fi
pr.worktree_cleaned = true

gt create "<pr.branch>" --no-interactive
git cat-file -t "<commit_sha>"
git cherry-pick <base_sha>..<commit_sha> --allow-empty
```

**Cherry-pick conflicts:** orchestrator resolves directly (read files, merge intents, remove markers, `git add`, `git cherry-pick --continue`); unresolvable → abort, mark PR failed, cascade-skip, continue stack.

**Epilogue (once after all PRs):**

```bash
gt submit --stack --no-edit --no-interactive
```

Do **not** set `graphite_stack_submitted` here — wait until Step 8b completes.

##### Step 8a (plain-git mode): Build the Stack

```bash
test -z "$(git status --porcelain)" || { echo "Working tree dirty; aborting"; exit 1; }
git fetch origin main
git checkout main
git reset --hard origin/main
parent_branch="main"
```

Per PR (linearized order, skip failed/skipped):

```bash
if [ -n "<pr.worktree_path>" ] && [ -d "<pr.worktree_path>" ]; then
  grok worktree rm --force "<pr.worktree_path>"
fi
pr.worktree_cleaned = true

git checkout -B "<pr.branch>" "$parent_branch"
git cat-file -t "<commit_sha>"
git cherry-pick <base_sha>..<commit_sha> --allow-empty
git push --force-with-lease origin "<pr.branch>"   # retry once after 5s on failure
parent_branch="<pr.branch>"
```

Record progress in `stack_assembly_progress`. On push failure after retry: mark PR failed, cascade-skip, **do not advance `parent_branch`**. Cherry-pick conflict handling same as Graphite mode; unresolvable → `git cherry-pick --abort`, `git checkout main`, mark failed, do not advance `parent_branch`.

Do **not** set `graphite_stack_submitted` until Step 8b completes.

##### Step 8b (Graphite mode): Collect PR URLs

After `gt submit` succeeds:

```bash
gt ls --json
```

Parse PR URLs per branch. Store in `pr_urls` (plain URL strings). Persist `pr_urls`. Set `graphite_stack_submitted = true`.

Report: `"Stack submitted: <N> PRs. URLs: [...]"`

##### Step 8b (plain-git mode): Collect PR URLs

After all branches are pushed, derive a GitHub-style compare URL for each branch in stack order. Branch prefix: `brownfield/<BROWNFIELD_ID>-*`.

```bash
remote_url=$(git config --get remote.origin.url)
```

Parse `remote_url` into `(host, owner, repo)`. Accept any of these forms, in order:

1. `git@<host>:<owner>/<repo>[.git]` (canonical SSH)
2. `ssh://git@<host>[:port]/<owner>/<repo>[.git]` (scheme-prefixed SSH)
3. `https://[<user>[:<pass>]@]<host>/<owner>/<repo>[.git][/]` (HTTPS, optionally with embedded credentials and/or trailing slash)

A pragmatic regex that captures all three (operate against the trimmed remote URL):

```
^(?:git@|ssh://(?:[^@]+@)?|https?://(?:[^@/]+@)?)([^:/]+)[:/](?:[^/]+/)*([^/]+)/([^/]+?)(?:\.git)?/?$
```

Capture groups: `host`, `owner`, `repo`. **Strip any `user[:pass]@` segment before logging the URL anywhere** to avoid leaking credentials embedded in the remote URL.

- If `host` does not match `github.com` or `github.*` (e.g., `github.example.com` for GHE), or if the regex fails entirely, the remote is non-GitHub. Skip compare-URL synthesis and skip `gh pr create` (even if `--auto-pr` was set). Instead, populate `pr_urls` with `{branch: <pr.branch>, url: null, kind: "pushed-only", note: "non-GitHub remote (<remote_url with credentials stripped>) — open a PR via your forge UI"}` for each pushed branch. Continue to Step 8c.

Otherwise, for each PR in linearized stack order, compute:

```
compare_url = "https://<host>/<owner>/<repo>/compare/<parent_branch>...<pr.branch>?expand=1"
```

where `<parent_branch>` is the branch immediately below this PR in the stack (or `main` for the bottom).

`pr_urls` in plain-git mode is a list of objects, one per pushed branch in stack order:

```json
{
  "branch": "<pr.branch>",
  "url": "<URL string or null>",
  "kind": "pr" | "compare" | "pushed-only",
  "note": "<optional explanatory string>"
}
```

The `note` field is optional: populated for `pushed-only` entries and may be attached to `compare` entries that resulted from a failed `gh pr create` invocation.

**If `auto_pr_flag == true` AND `gh_available == true` AND host is GitHub/GHE:** create draft PRs sequentially:

```bash
gh pr create --base "<parent_branch>" --head "<pr.branch>" --fill --draft
```

Capture stdout (created PR URL) and append an entry with `kind: "pr"`. If `gh pr create` fails for a single branch, log the failure, append an entry with `kind: "compare"` and the synthesized compare URL (attach error in `note`), and continue. Sequential — never parallel — to preserve ordering.

**Otherwise (no `--auto-pr`, or no `gh`):** populate every entry with `kind: "compare"` and the synthesized compare URL. Build `pr_create_commands`:

```
gh pr create --base <parent_branch> --head <pr.branch> --fill --draft
```

one per PR in stack order.

Persist `pr_urls`, `pr_create_commands`. Set `graphite_stack_submitted = true`.

##### Step 8c: Stack Assembly Reporting

Report using the variant that matches the mix of `pr_urls` entry `kind`s (plain-git) or Graphite URL list:

- **All `kind: "pr"`:** `"Stack pushed and PRs created: <N> branches. URLs: [...]"`
- **All `kind: "compare"`:** `"Stack pushed: <N> branches. Open these compare URLs (or run the gh pr create commands) to open PRs: [...]"`
- **Mixed `kind: "pr"` and `kind: "compare"`:** `"Stack pushed: <N> branches. <X> PRs were created via gh, <Y> need to be opened manually via the printed compare URLs."`
- **Any `kind: "pushed-only"`:** `"Stack pushed: <N> branches to non-GitHub remote. Open PRs via your forge UI."`
- **Graphite mode (plain URL strings in `pr_urls`):** `"Stack submitted: <N> PRs. URLs: [...]"`

Include `pr_urls` and `pr_create_commands` in state for Final Report. Render `note` verbatim when present on plain-git entries.

#### Step 9: Execute Cleanup

**Normative order:** Run Step 9 **after** Phase 6 (Inline Path Completion step 4). Do not delete exec summaries before verify reads them.

Kill implementer/reviewer subagents:

```
for each pr in dag.nodes:
    if pr.subagent_id is not null:
        kill_command_or_subagent(pr.subagent_id)
    for each config in pr.reviewer_configs:
        if config.subagent_id is not null:
            kill_command_or_subagent(config.subagent_id)
```

Remove remaining worktrees (`worktree_cleaned` guard):

```bash
for each pr in dag.nodes where worktree_path is not null and not pr.worktree_cleaned:
    if directory "<worktree_path>" exists:
        grok worktree rm --force "<worktree_path>"
    pr.worktree_cleaned = true
```

Remove per-PR exec summary/review temps:

```bash
rm -f /tmp/grok-brownfield-exec-summary-${BROWNFIELD_ID}-*.md
rm -f /tmp/grok-brownfield-exec-review-${BROWNFIELD_ID}-*.md
```

**Keep `state_file`** for resume/history (strip volatile fields on `phase: "complete"` — see Inline Path Completion). `chmod 600` all retained artifacts.

#### Inline Path Completion

**Normative order:** Step 8 (8a→8b→8c) → Phase 6 gate → Step 9 cleanup → memory flush → Final Report.

1. Count `prs_completed`, `prs_failed`, `prs_skipped` from `dag.nodes`
2. Set `exec_summary_glob = "/tmp/grok-brownfield-exec-summary-${BROWNFIELD_ID}-*.md"`
3. Collect execute review patterns into `issue_patterns`
4. **Phase 6 gate** — if `prs_completed < 1`, cancel `post-verify`; else set `phase: "verify"`, persist, run Phase 6 (verify reads exec summaries **before** Step 9 rm)
5. **Step 9 cleanup** (exec artifact rm)
6. Memory flush → Final Report → set `phase: "complete"`; strip volatile fields from `state_file` (`worktree_path`, `commit_sha`, `user_instructions`, `reviewer_configs` per node); persist

### Delegated Execution Path (FALLBACK — `--delegate-execute`)

When `delegate_execute_flag` is true:

1. Read bundled `execute_plan_skill_path` via `read_file`
2. Read `instructions_file`; store as `user_instructions`
3. Follow execute-plan as nested orchestrator — do **not** merely echo a slash command
4. Invoke with **file-only instructions** (no secrets in argv):
   ```
   /execute-plan <design_doc_file> --effort 1 --concurrency <max_concurrent> --instructions-file <instructions_file>
   ```
   If `--instructions-file` unsupported, use `--instructions` with path reference only: `"See instructions at <instructions_file>"` — never embed scrubbed content in process args.
5. Forward flags when set: append `--no-graphite` if `no_graphite_flag`; append `--auto-pr` if `auto_pr_flag`

**Delegation start persistence:** When execute-plan Setup reports `PLAN_ID`, immediately persist `execute_plan_id`, `phase: "execute_delegated"`, `exec_summary_glob: "/tmp/grok-exec-summary-${execute_plan_id}-*.md"`; `chmod 600` state_file.

**Delegated Path Completion:**

1. Merge stats from `/tmp/grok-exec-plan-${execute_plan_id}.json` (`dag` node statuses, `pr_urls`, `prs_completed`, etc.)
2. chmod-fix delegated artifacts
3. Collect review patterns into `issue_patterns`
4. **Phase 6 gate** — if `prs_completed < 1`, cancel `post-verify`; else set `phase: "verify"`, persist, run Phase 6
5. Memory flush → Final Report → `phase: "complete"` (strip volatile fields); persist

**Delegated resume:** `/brownfield --resume` rejected when `phase == "execute_delegated"`. Use `/execute-plan --resume <execute_plan_id>`.

### Without `--execute`

Suggest primary path:

```
/brownfield --execute --effort <N> <project_context>
```

Alternative (lower review rigor):

```
/brownfield --execute --delegate-execute <project_context>
```

or `/execute-plan <design_doc_file> --effort 1`.

## Phase 6: Post-Implementation Verification

Runs only when `prs_completed >= 1`.

| Path | `exec_summary_glob` |
|------|---------------------|
| Inline | `/tmp/grok-brownfield-exec-summary-${BROWNFIELD_ID}-*.md` |
| Delegated | `/tmp/grok-exec-summary-${execute_plan_id}-*.md` |

Spawn `[verify]` subagent using **Verify Specialist** template. Include validated `execute_plan_id` when delegated.

**Wait for completion (mirror Phase 2):**
1. `spawn_subagent` with `background: false` (or block on `task_id` if background)
2. `get_command_or_subagent_output(task_id=..., block=true)`
3. If subagent fails → report error; note in Final Report; still run memory flush
4. Confirm `/tmp/grok-brownfield-verify-${BROWNFIELD_ID}.md` exists
5. `chmod 600` verify file if needed

Report: `"Post-implementation verification complete."`

## Memory Flush

**Follow `/implement` Step 6 verbatim** (6a–6d) with brownfield substitutions.

| implement | brownfield |
|-----------|------------|
| `IMPL_ID` | `BROWNFIELD_ID` |
| `review_file` | `design_review_file` + execute review files |
| `run.description` | `"Brownfield: <short project_context>"` |
| `run.specializations` | analysis tags + execute review tags |
| `run.rounds` | `round_count` + execute review rounds |
| Temp JSON | `/tmp/grok-brownfield-mem-${BROWNFIELD_ID}.json` |

**Timing:** once — after Phase 4b (no execute); after Phase 5 completion post-Phase-6-gate (execute path, including 0-PR skip).

### Step 6a: Collect & Categorize

Use `issue_patterns` accumulated across merge + design review (+ execute reviews). **Generalize each pattern** — strip file/variable/domain names; rewrite as reusable principles:
- Bad: "JWT token not validated for expiration" → Good: "Missing expiration/TTL validation on tokens or credentials"
- Bad: "No test for `handleUserAuth` error path" → Good: "Missing tests for error/edge case paths"
- If already general, keep as-is; collapse duplicates

Categorize: Error Handling, Testing, Security, Code Quality, Naming, Documentation, Performance, Architecture, Assumptions.

### Step 6b: Harmonize Phrasing

Against `existing_patterns_snapshot`, match semantically equivalent descriptions; use exact existing description string when matched. Dedup within this run's list too.

### Step 6c–6d

Build JSON spec; write `/tmp/grok-brownfield-mem-${BROWNFIELD_ID}.json`; `chmod 600` immediately after write; `python3 <memory_helper_path> update < /tmp/grok-brownfield-mem-${BROWNFIELD_ID}.json`. Graceful degradation on failure.

## Cleanup

After Final Report:

```bash
rm -f <design_review_file> /tmp/grok-brownfield-mem-${BROWNFIELD_ID}.json <instructions_file>
rm -f /tmp/grok-brownfield-exec-summary-${BROWNFIELD_ID}-*.md  # if not already removed in Step 9
rm -f /tmp/grok-brownfield-exec-review-${BROWNFIELD_ID}-*.md
rm -f /tmp/grok-brownfield-analysis-${BROWNFIELD_ID}/*.md  # optional
if cleanup_deliverables:
    rm -f <state_file> /tmp/grok-brownfield-verify-${BROWNFIELD_ID}.md
```

**Default post-run retention:** Keep primary deliverables (intent, assumptions, analysis merged, design doc, summary) unless user passes `--cleanup-deliverables` (document in Final Report).

**Always remove:** design_review_file, mem temp JSON, instructions_file, per-specialist analysis files.

**With `--cleanup-deliverables`:** After Final Report, also `rm -f` `state_file` and verify file (`/tmp/grok-brownfield-verify-${BROWNFIELD_ID}.md`).

**Manual scrub (Final Report bullet 13):**
```bash
rm -f /tmp/grok-brownfield-*-${BROWNFIELD_ID}*  # removes all run artifacts for this run
```

## Final Report

Present after memory flush. Read deliverables before cleanup.

### Required bullets (14)

1. **Run metadata** — `BROWNFIELD_ID`, effort, `--execute`, `project_context`, `workspace_root`
2. **Intent brief** — path; 1-line goal
3. **Assumptions summary** — counts; non-blocking low-confidence items
4. **Analysis** — `analysis_merged_file`; specialist composition; `analysis_round_count`
5. **Design document** — `design_doc_file`
6. **Design review stats** — `round_count`; `total_issues_by_severity`
7. **Key Decisions** — excerpt
8. **Open Questions** — resolved or none
9. **PR Plan** — summary or path
10. **Execution** — PRs completed/failed/skipped; `execute_plan_id` if delegated; resume command by `phase`
11. **Verification** — verify file path; success criteria table (or "skipped — 0 PRs completed")
12. **Memory update** — patterns; path; created vs updated
13. **Cleanup** — removed vs retained; manual scrub command
14. **Suggested follow-ups** — `/brownfield --execute --effort N`, `/brownfield --resume <BROWNFIELD_ID>` (inline), `/execute-plan --resume <id>` (delegated), `/implement`

## In-Progress Reporting

| Event | Message |
|-------|---------|
| Setup | `"Brownfield run ${BROWNFIELD_ID}, effort N, execute: true/false"` |
| Intent (effort 1) | `"Intent brief captured. Starting analysis pass 1 (Architecture)..."` |
| Intent (effort ≥2) | `"Intent brief captured. Starting analysis pass 1 (Architecture + Product-Intent)..."` |
| Pass 1 done | `"Pass 1 complete. Starting analysis pass 2 (K specialists)..."` |
| Analysis merge | `"Analysis complete. N assumptions (W need confirmation)."` |
| Escalation | `"Assumption A-### needs your input."` |
| Design drafted | `"Design document drafted. Starting design review..."` |
| Design 0 issues | `"Design review passed with 0 issues. Finalizing..."` |
| Execute launch | `"Executing PR Plan: M PRs, concurrency C, effort N, mode: inline\|delegated"` |
| Tool detection | `"Graphite mode: ..."` or `"Plain-git mode: ..."` |
| Delegation start | `"Delegated to execute-plan PLAN_ID=...; state persisted"` |
| Per PR | `"Launching <pr.id>..."`, review rounds, fix cycles (mirror execute-plan) |
| Stack assembly | `"All PRs complete. Building Graphite\|git branch stack..."` |
| Inline resume | `"Resuming brownfield execute ${BROWNFIELD_ID}..."` |
| Verify | `"Post-implementation verification complete."` |
| Memory | Mirror implement memory flush messages |

## Rules

- **Tool-call discipline** — paired `spawn_subagent` for every launch claim
- **Bundled path resolution** — `bundled_skills_root` algorithm; never `../shared/personas` from user scope
- **Memory via implement helper** — single `update` per run
- **0 open issues exit** — design review: critical/major/minor/nit
- **Assumptions first-class** — escalate blocking before Phase 3
- **Two-pass analysis** — wait protocol between passes
- **resume_from** — design review, Phase 2a re-runs
- **Merge only** — orchestrator concatenates/dedupes; no new findings
- **Secrets** — redact in artifacts; file:line in user messages
- **Inline execute primary** — effort scales per-PR reviewers via `/implement` reviewer_configs algorithm
- **Delegated execute fallback** — `--delegate-execute` only; same-session Phase 6 + memory + Final Report
- **Subagent Worktree Protocol** — fetch without refspec; `commit_sha` authoritative; rm worktree before branch mutation
- **Execute resume** — `--resume` with `phase: execute_inline` jumps to Phase 5 Step 7

## Security & Privacy

- `umask 077` before writes; `chmod 600` on all artifacts and `state_file`
- Memory file `0o600` via `memory.py`
- Remap security-auditor native severities (critical/high/medium/low) → workflow severities (bug/suggestion/nit) in analysis artifacts
- `/tmp` deliverables have no TTL — default keep deliverables; optional `--cleanup-deliverables` and manual scrub documented in Final Report
- Delegated execute-plan artifacts: brownfield chmod-fixes post-hoc; warn when any remain world-readable