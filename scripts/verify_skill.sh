#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# verify_skill.sh — structure verification for /brownfield skill (PR 3 + PR 2b/2c)
#
# Validates bundled fallback paths only; does not exercise skills-list override
# resolution (known limitation — see CONTRIBUTING.md).
#
# Pattern categories:
#   - NORMATIVE_WIRING: tokens that must exist for orchestration correctness
#   - STRUCTURAL_GUARDS: anchored headings and phase tokens
#   - PROSE_GUARDS: narrowly scoped phrases tied to spec invariants (minimize edits)
#
# Frontmatter description/quality beyond presence is intentionally out-of-scope.
#
# Run: bash scripts/verify_skill.sh
# Also run: bash tests/test_verify_skill.sh
umask 077
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_MD="${SKILL_DIR}/SKILL.md"
RESOLVE_SCRIPT="${SKILL_DIR}/scripts/resolve_bundled_root.sh"
BUNDLED_SKILLS_ROOT="$("${RESOLVE_SCRIPT}")"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*"
}

grep_skill() {
  grep -qE -- "$1" "${SKILL_MD}" || fail "SKILL.md missing pattern: $1"
}

# macOS pipefail: grep -q closes the pipe early; use process substitution.
frontmatter_grep() {
  grep -q "$@" <(sed -n "${FM_START},${FM_END}p" "${SKILL_MD}")
}

extract_section() {
  local start_pattern="$1"
  local end_pattern="$2"
  awk -v start="${start_pattern}" -v end="${end_pattern}" '
    $0 ~ start { capture=1; next }
    capture && $0 ~ end { exit }
    capture { print }
  ' "${SKILL_MD}"
}

[[ -f "${SKILL_MD}" ]] || fail "SKILL.md not found at ${SKILL_MD}"
[[ -x "${RESOLVE_SCRIPT}" ]] || fail "resolve_bundled_root.sh not executable"

# --- Frontmatter checks (fence-based) ---
FM_START=$(grep -n '^---$' "${SKILL_MD}" | head -1 | cut -d: -f1)
FM_END=$(grep -n '^---$' "${SKILL_MD}" | sed -n '2p' | cut -d: -f1)
[[ -n "${FM_START}" && -n "${FM_END}" && "${FM_END}" -gt "${FM_START}" ]] \
  || fail "frontmatter --- fences missing or malformed"

frontmatter_grep '^name: brownfield$' \
  || fail "frontmatter name: brownfield missing"
frontmatter_grep '^description:' \
  || fail "frontmatter description missing"
frontmatter_grep '^when-to-use:' \
  || fail "frontmatter when-to-use missing"
frontmatter_grep '^argument-hint:' \
  || fail "frontmatter argument-hint missing"
frontmatter_grep 'compatibility:' \
  || fail "frontmatter compatibility missing"

for flag in '--resume' '--execute' '--delegate-execute' '--no-graphite' '--auto-pr' '--effort' '--concurrency' '--cleanup-deliverables'; do
  frontmatter_grep -F -- "${flag}" \
    || fail "argument-hint must include ${flag}"
done
pass "frontmatter fields and flags present"

# --- Required phase / section headings (STRUCTURAL_GUARDS — anchored) ---
REQUIRED_HEADING_PATTERNS=(
  '^## Orchestrator Identity'
  '^## Tool-Call Discipline'
  '^## Protocol Enforcement & Phase Gates'
  '^## Context Budget Protocol'
  '^## Effort Model'
  '^## Excellence Doctrine'
  '^## Todo Scaffold'
  '^## Invocation'
  '^## Phase 0: Setup'
  '^## Phase 0b: Source Principles Ingestion'
  '^## Phase 1: Intent Discovery'
  '^## Phase 1b: Orchestration Decomposition'
  '^## Phase 2: Assumption-Aware Analysis'
  '^## Phase 2a: Assumption Escalation'
  '^## Phase 3: Consolidated Design Document'
  '^## Phase 4: Design Review Loop'
  '^## Phase 4b: Summarize and Ask Open Questions'
  '^## Phase 5: Execution'
  '^## Phase 6: Post-Implementation Verification'
  '^## Memory Flush'
  '^## Final Report'
  '^### Architecture Specialist'
  '^### Product-Intent Specialist'
  '^### Code Specialist'
  '^### Code-2 Specialist'
  '^### Tests Specialist'
  '^### Security Specialist'
  '^### Documentation Specialist'
  '^### Verify Specialist'
  '^#### Subagent Worktree Protocol'
  '^#### Two Assembly Modes'
  '^#### Execute Todo Scaffold'
  '^#### Step 0\.5: Tool Detection'
  '^#### Step 1: Parse PR Plan DAG'
  '^#### Step 2: DAG Processing'
  '^#### Step 3: Branch Preparation'
  '^#### Step 4: Execution Loop'
  '^#### Step 5: Per-PR Review'
  '^#### Step 6: Failure Handling'
  '^#### Step 7: Resumption'
  '^#### Step 8: Stack Assembly'
  '^##### Step 8c: Stack Assembly Reporting'
  '^#### Step 9: Execute Cleanup'
  '^### Inline Execution Path'
  '^### Delegated Execution Path'
)

for pattern in "${REQUIRED_HEADING_PATTERNS[@]}"; do
  grep -qE -- "${pattern}" "${SKILL_MD}" || fail "required heading missing: ${pattern}"
done
pass "required phase headings present (anchored)"

# --- Compound section anchors (A-010 — run before global greps for precise failures) ---
DOCTRINE_SECTION="$(extract_section '^## Excellence Doctrine' '^## ')"
[[ -n "${DOCTRINE_SECTION}" ]] || fail "Excellence Doctrine section missing"
echo "${DOCTRINE_SECTION}" | grep -q 'people affected' \
  || fail "Excellence Doctrine missing utility gate: people affected"
echo "${DOCTRINE_SECTION}" | grep -q 'utility gain' \
  || fail "Excellence Doctrine missing utility gate: utility gain"
echo "${DOCTRINE_SECTION}" | grep -q 'cannot override' \
  || fail "Excellence Doctrine missing 0-open-issues cannot-override cross-ref"
echo "${DOCTRINE_SECTION}" | grep -q '### 4\. The Algorithm' \
  || fail "Excellence Doctrine missing The Algorithm subsection"
echo "${DOCTRINE_SECTION}" | grep -qE 'Question requirements|^\*\*Question' \
  || fail "Excellence Doctrine missing Algorithm Question step"
echo "${DOCTRINE_SECTION}" | grep -q 'Delete' \
  || fail "Excellence Doctrine missing Algorithm Delete step"
pass "Excellence Doctrine compound anchors present"

CONTEXT_BUDGET_SECTION="$(extract_section '^## Context Budget Protocol' '^## ')"
[[ -n "${CONTEXT_BUDGET_SECTION}" ]] || fail "Context Budget Protocol section missing"
echo "${CONTEXT_BUDGET_SECTION}" | grep -qE 'CONTEXT_BUDGET_CAP_CHARS|400,?000|400000' \
  || fail "Context Budget Protocol missing 400k cap constant"
echo "${CONTEXT_BUDGET_SECTION}" | grep -q 'pre-spawn' \
  || fail "Context Budget Protocol missing pre-spawn gate"
echo "${CONTEXT_BUDGET_SECTION}" | grep -q 'grok-brownfield-spawn-log' \
  || fail "Context Budget Protocol missing spawn log path"
echo "${CONTEXT_BUDGET_SECTION}" | grep -q 'excerpt-only' \
  || fail "Context Budget Protocol missing excerpt-only transport"
echo "${CONTEXT_BUDGET_SECTION}" | grep -qE 'MUST NOT inject full.*SKILL|never.*full SKILL' \
  || fail "Context Budget Protocol missing full-SKILL prohibition (KD-013)"
pass "Context Budget Protocol compound anchors present"

SLOT_ALGORITHM_SECTION="$(extract_section '^### Slot Algorithm' '^### ')"
[[ -n "${SLOT_ALGORITHM_SECTION}" ]] || fail "Slot Algorithm (pass-2) subsection missing"
echo "${SLOT_ALGORITHM_SECTION}" | grep -q 'sort selected_optional by PRIORITY' \
  || fail "Slot Algorithm missing sort selected_optional by PRIORITY"
echo "${SLOT_ALGORITHM_SECTION}" | grep -q 'num_code = 2 if effort == 5 else 1' \
  || fail "Slot Algorithm missing effort-5 dual code specialists"
pass "effort-5 pass-2 slot algorithm present"

STEP5_SECTION="$(extract_section '^#### Step 5: Per-PR Review' '^#### Step 6')"
[[ -n "${STEP5_SECTION}" ]] || fail "Step 5 Per-PR Review section missing"
echo "${STEP5_SECTION}" | grep -q 'total_slots = 6' \
  || fail "Step 5 missing effort-5 total_slots = 6"
echo "${STEP5_SECTION}" | grep -q 'matched_specialists' \
  || fail "Step 5 missing matched_specialists roster algorithm"
echo "${STEP5_SECTION}" | grep -q 'matched_specialists.append' \
  || fail "Step 5 missing matched_specialists.append wiring"
echo "${STEP5_SECTION}" | grep -q 'specialists = matched_specialists\[:total_slots - 1\]' \
  || fail "Step 5 missing specialist slot assignment from matched_specialists"
pass "effort-5 execute reviewer roster algorithm present"

# --- NORMATIVE_WIRING content checks (structural tokens preferred) ---
grep_skill '/bundled/skills/'
grep_skill '\$HOME/\.grok/bundled/skills'
grep_skill 'shared/personas'
grep_skill 'never.*shared/personas'
grep_skill 'memory_helper_path'
grep_skill 'implement/SKILL\.md'
grep_skill 'execute_delegated'
grep_skill 'execute_inline'
grep_skill 'execute_pending'
grep_skill 'exec_summary_glob'
grep_skill 'execute_plan_id'
grep_skill '# Intent Brief'
grep_skill 'orchestration_plan_file'
grep_skill 'orchestration_plan_written'
grep_skill '# Orchestration Decomposition Plan'
grep_skill 'Phase 1b'
grep_skill 'orchestration-decomposition'
grep_skill 'Protocol Enforcement'
grep_skill 'Phase gate matrix'
grep_skill 'Violation handling'
grep_skill 'Effort announcement'
grep_skill 'Do not launch Phase 2 until'
grep_skill 'Delegation prompt rule'
grep_skill 'coordinate only'
grep_skill 'Context Budget Protocol'
grep_skill '400,?000|400000'
grep_skill 'pre-spawn'
grep_skill 'spawn log'
grep_skill 'spawn_log_file'
grep_skill 'excerpt-only'
grep_skill 'MUST NOT inject full.*SKILL|never.*full SKILL'
grep_skill 'Phase 0b|Source Principles Ingestion'
grep_skill 'grok-brownfield-source-merged'
grep_skill 'grok-brownfield-spawn-log'
grep_skill 'Est\. input chars'
grep_skill 'Budget status'
grep_skill 'Transport mode'
grep_skill '# Assumptions Register'
grep_skill 'get_command_or_subagent_output'
grep_skill '\[verify\]'
grep_skill 'post-verify'
grep_skill 'max_concurrent = min\(max'
grep_skill 'sort selected_optional by PRIORITY'
grep_skill 'intent_text'
grep_skill 'intent_additions\.append\("security"\)'
grep_skill 'intent_only'
grep_skill 'in addition to effort-mandated'
grep_skill 'cleanup_deliverables'
grep -qF -- '--cleanup-deliverables' "${SKILL_MD}" \
  || fail "SKILL.md missing literal flag: --cleanup-deliverables"
grep -qF -- '--delegate-execute' "${SKILL_MD}" \
  || fail "SKILL.md missing literal flag: --delegate-execute"
grep -qF -- '--delegate-execute requires --execute' "${SKILL_MD}" \
  || fail "SKILL.md missing pattern: --delegate-execute requires --execute"
grep_skill 'IGNORE persona severity labels'
grep_skill '\[REDACTED\]'
grep_skill 'Path allowlist'
grep_skill 'prs_completed'
grep_skill '\*\*not\*\* hardcoded 1'
grep_skill 'Use brownfield `effort`'
grep_skill 'Restore.*effort'
grep_skill 'no_graphite_flag'
grep_skill 'auto_pr_flag'
grep_skill 'pr_urls'
grep_skill 'pr_create_commands'
grep_skill 'stack_assembly_progress'
grep_skill 'worktree_cleaned'
grep_skill 'brownfield/<BROWNFIELD_ID>-'
grep_skill 'git push --force-with-lease'
grep_skill 'wait_commands_or_subagents'
grep_skill 'cascade_skip'
grep_skill 'stack_assembly_started'
grep_skill 'graphite_stack_submitted'
grep_skill 'linearized_order'
grep_skill 'brownfield_id mismatch'
grep_skill 'workspace_root invalid'
grep_skill 'invalid artifact path'
grep_skill 'unknown phase'
grep_skill 'delegate_execute_flag = state.delegate_execute'
grep_skill 'instructions-file'
grep_skill 'matched_specialists.append'
grep_skill 'plan_alignment'
grep_skill 'Normative order.*Step 8.*Phase 6.*Step 9'
grep_skill 'issue_patterns'
grep_skill 'Building `specialist_configs`'
grep_skill 'reviewer_configs'
grep_skill 'Building reviewer_configs'
grep_skill 'suffix_map\[specialist\]'
grep_skill 'kill_command_or_subagent'
grep_skill 'You are a thorough test engineer'
grep_skill 'Plan Alignment Specialist'
grep_skill 'kind: "pushed-only"'
grep_skill 'Stack pushed and PRs created'
grep_skill 'git rev-parse --show-toplevel'
grep_skill 'instructions_file'
grep_skill 'grok-brownfield-verify-'
grep_skill 'grok-brownfield-state-'
grep_skill 'grok-exec-summary-'
grep_skill 'grok-brownfield-exec-summary-'
grep_skill 'grok-brownfield-exec-review-'
grep_skill 'Runs only when.*prs_completed >= 1'
grep_skill 'This run delegated to execute-plan'
grep_skill 'tests\.md'
grep_skill 'design_doc_file'
grep_skill 'Memory timing \(single flush per run\)'
grep_skill 'Rule 1 — fetch without a destination refspec'
grep_skill 'commit_sha.*authoritative'
grep_skill 'grok worktree rm --force'
grep_skill 'Plain-git mode'
grep_skill 'Graphite mode'
grep_skill 'total_slots = 5'
grep_skill 'total_slots = 6'
grep_skill '--effort.*Scales \*\*both\*\* analysis'
grep_skill 'PRIMARY'
grep_skill 'FALLBACK'
grep_skill 'Phase 5 Step 7'
grep_skill '## Excellence Doctrine'
grep_skill 'First Principles Decomposition'
grep_skill 'The Algorithm'
grep_skill 'Delete'
grep_skill 'Corps delegation|wedge'
grep_skill '0 open issues'
grep_skill 'bottleneck'
grep_skill 'Utility score'
grep_skill 'Intent Traceability Matrix'
grep_skill 'Thinking in limits'
grep_skill 'idiot index'
grep_skill 'Platonic Ideal'
grep_skill 'short-description'
grep_skill '<project path or description>'
pass "design-mandated content patterns present"

# Delegated Execution Path must mandate context-budget check + excerpt-only handoff
DELEGATED_SECTION="$(extract_section '^### Delegated Execution Path' '^### ')"
[[ -n "${DELEGATED_SECTION}" ]] || fail "Delegated Execution Path section missing"
echo "${DELEGATED_SECTION}" | grep -qE 'context.budget|Context.budget|context budget' \
  || fail "Delegated Execution Path missing context-budget check"
echo "${DELEGATED_SECTION}" | grep -q 'excerpt-only' \
  || fail "Delegated Execution Path missing excerpt-only handoff"
echo "${DELEGATED_SECTION}" | grep -q 'instructions_file' \
  || fail "Delegated Execution Path missing instructions_file reference"
pass "Delegated Execution Path context-budget wiring present"

# Implementer must be fail-fast (scoped to Persona Resolution — not whole SKILL.md)
PERSONA_SECTION="$(extract_section '^### Persona Resolution' '^### ')"
[[ -n "${PERSONA_SECTION}" ]] || fail "Persona Resolution section missing"
echo "${PERSONA_SECTION}" | grep -qE 'Required \(fail-fast\).*implementer|implementer.*fail-fast' \
  || fail "implementer persona must be fail-fast in Persona Resolution"
if echo "${PERSONA_SECTION}" | grep -qE 'implementer.*warn-only|warn-only.*implementer'; then
  fail "implementer persona must be fail-fast, not warn-only"
fi
pass "implementer persona fail-fast"

# No stale inline-not-implemented rejection
if grep -qE 'Inline execute resume not implemented|inline execute not supported' "${SKILL_MD}"; then
  fail "stale inline-execute-not-implemented messaging still present"
fi
pass "inline execute resume supported"

# Memory timing consistency
grep_skill 'Do not call'
grep_skill 'at both Phase 4b and'
if grep -qE 'update.*after Phase 4b \(and Phase 6' "${SKILL_MD}"; then
  fail "memory timing contradiction: old dual-update phrasing"
fi
pass "memory timing consistent (single flush)"

# Final Report bullets
FINAL_BULLETS=$(awk '/^## Final Report/,/^## In-Progress Reporting/' "${SKILL_MD}" | grep -cE '^[0-9]+\. \*\*' || true)
[[ "${FINAL_BULLETS}" -ge 15 ]] || fail "Final Report needs >= 15 bullets (found ${FINAL_BULLETS})"
pass "Final Report has ${FINAL_BULLETS} bullets"

# --- Bundled skills root (fallback path only; override resolution not tested) ---
[[ -d "${BUNDLED_SKILLS_ROOT}" ]] \
  || fail "bundled_skills_root not found (set BUNDLED_SKILLS_ROOT or install Grok Build)"
pass "bundled_skills_root exists (resolved)"

[[ -f "${BUNDLED_SKILLS_ROOT}/implement/SKILL.md" ]] \
  || fail "bundled implement/SKILL.md missing"
pass "bundled implement/SKILL.md exists"

PERSONAS=(
  design-doc-writer
  design-doc-reviewer
  implementer
  reviewer
  security-auditor
)

for persona in "${PERSONAS[@]}"; do
  persona_path="${BUNDLED_SKILLS_ROOT}/shared/personas/${persona}.md"
  [[ -f "${persona_path}" ]] || fail "persona missing: ${persona}"
  [[ -s "${persona_path}" ]] || fail "persona empty: ${persona}"
  pass "persona resolves: ${persona}"
done

# --- memory.py snapshot with JSON type validation ---
MEMORY_HELPER="${BUNDLED_SKILLS_ROOT}/implement/scripts/memory.py"
[[ -f "${MEMORY_HELPER}" ]] || fail "memory.py missing"

GIT_CWD="${SKILL_DIR}"
while [[ "${GIT_CWD}" != "/" ]]; do
  if git -C "${GIT_CWD}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    break
  fi
  GIT_CWD="$(dirname "${GIT_CWD}")"
done

MEM_TEST_DIR=""
if ! git -C "${GIT_CWD}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  MEM_TEST_DIR="$(mktemp -d)"
  git -C "${MEM_TEST_DIR}" init -q
  GIT_CWD="${MEM_TEST_DIR}"
fi

SNAPSHOT_OUT=$(cd "${GIT_CWD}" && python3 "${MEMORY_HELPER}" snapshot) \
  || fail "memory.py snapshot failed (exit != 0)"

[[ -n "${MEM_TEST_DIR}" ]] && rm -rf "${MEM_TEST_DIR}"

echo "${SNAPSHOT_OUT}" | python3 -c '
import json, sys
data = json.load(sys.stdin)
for key in ("common_issues", "recent_runs", "exists"):
    if key not in data:
        raise SystemExit(f"missing key: {key}")
if not isinstance(data["common_issues"], list):
    raise SystemExit("common_issues must be list")
if not isinstance(data["recent_runs"], list):
    raise SystemExit("recent_runs must be list")
if not isinstance(data["exists"], bool):
    raise SystemExit("exists must be bool")
print("ok")
' || fail "memory.py snapshot returned invalid JSON or wrong types"

pass "memory.py snapshot exits 0 with valid typed JSON"

echo ""
echo "All brownfield skill structure checks passed."