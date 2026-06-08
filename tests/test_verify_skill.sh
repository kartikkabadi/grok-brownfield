#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# test_verify_skill.sh — negative/regression tests for verify_skill.sh
#
# Run both verification scripts:
#   bash scripts/verify_skill.sh
#   bash tests/test_verify_skill.sh
#
# Note: the unreadable-cwd memory.py test may SKIP on permissive filesystems (see CONTRIBUTING.md).
#
umask 077
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERIFY="${SKILL_DIR}/scripts/verify_skill.sh"
RESOLVE="${SKILL_DIR}/scripts/resolve_bundled_root.sh"
SOURCE_SKILL="${SKILL_DIR}/SKILL.md"
BUNDLED_SRC="$("${RESOLVE}")"
TMPROOT="$(mktemp -d)"
trap 'rm -rf "${TMPROOT}"' EXIT

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

# expect_fail LABEL EXPECTED_SUBSTRING COMMAND...
expect_fail() {
  local label="$1"
  local expect="$2"
  shift 2

  local stderr_file
  stderr_file="$(mktemp)"
  if "$@" 2>"${stderr_file}" >/dev/null; then
    cat "${stderr_file}" >&2
    rm -f "${stderr_file}"
    fail "${label}: expected non-zero exit"
  fi
  if ! grep -qF -- "${expect}" "${stderr_file}"; then
    echo "stderr was:" >&2
    cat "${stderr_file}" >&2
    rm -f "${stderr_file}"
    fail "${label}: expected stderr containing: ${expect}"
  fi
  rm -f "${stderr_file}"
  pass "${label}"
}

[[ -f "${VERIFY}" ]] || fail "verify_skill.sh not found"

# --- Positive control ---
bash "${VERIFY}" || fail "positive control: real skill should pass"
pass "positive control: real skill passes"

# --- Missing SKILL.md ---
MISSING_DIR="${TMPROOT}/no-skill"
mkdir -p "${MISSING_DIR}/scripts"
cp "${VERIFY}" "${MISSING_DIR}/scripts/verify_skill.sh"
cp "${RESOLVE}" "${MISSING_DIR}/scripts/resolve_bundled_root.sh"
chmod +x "${MISSING_DIR}/scripts/resolve_bundled_root.sh"
cp -R "${SKILL_DIR}/fixtures" "${MISSING_DIR}/fixtures"
expect_fail "missing SKILL.md" "SKILL.md not found" bash "${MISSING_DIR}/scripts/verify_skill.sh"

# --- Bad frontmatter name ---
BAD_NAME_DIR="${TMPROOT}/bad-name"
mkdir -p "${BAD_NAME_DIR}/scripts"
cp "${VERIFY}" "${BAD_NAME_DIR}/scripts/verify_skill.sh"
cp "${RESOLVE}" "${BAD_NAME_DIR}/scripts/resolve_bundled_root.sh"
chmod +x "${BAD_NAME_DIR}/scripts/resolve_bundled_root.sh"
cp -R "${SKILL_DIR}/fixtures" "${BAD_NAME_DIR}/fixtures"
cp "${SOURCE_SKILL}" "${BAD_NAME_DIR}/SKILL.md"
sed -i '' 's/^name: brownfield$/name: not-brownfield/' "${BAD_NAME_DIR}/SKILL.md" 2>/dev/null \
  || sed -i 's/^name: brownfield$/name: not-brownfield/' "${BAD_NAME_DIR}/SKILL.md"
expect_fail "bad name: brownfield" "frontmatter name: brownfield missing" bash "${BAD_NAME_DIR}/scripts/verify_skill.sh"

# --- Dropped frontmatter flag (--resume) ---
NO_RESUME_FLAG_DIR="${TMPROOT}/no-resume-flag"
mkdir -p "${NO_RESUME_FLAG_DIR}/scripts"
cp "${VERIFY}" "${NO_RESUME_FLAG_DIR}/scripts/verify_skill.sh"
cp "${RESOLVE}" "${NO_RESUME_FLAG_DIR}/scripts/resolve_bundled_root.sh"
chmod +x "${NO_RESUME_FLAG_DIR}/scripts/resolve_bundled_root.sh"
cp -R "${SKILL_DIR}/fixtures" "${NO_RESUME_FLAG_DIR}/fixtures"
cp "${SOURCE_SKILL}" "${NO_RESUME_FLAG_DIR}/SKILL.md"
sed -i '' 's/--resume //g' "${NO_RESUME_FLAG_DIR}/SKILL.md" 2>/dev/null \
  || sed -i 's/--resume //g' "${NO_RESUME_FLAG_DIR}/SKILL.md"
expect_fail "missing --resume flag" "argument-hint must include --resume" bash "${NO_RESUME_FLAG_DIR}/scripts/verify_skill.sh"

# --- Dropped Context Budget Protocol section (NO_CONTEXT_BUDGET) ---
NO_CONTEXT_BUDGET_DIR="${TMPROOT}/no-context-budget"
mkdir -p "${NO_CONTEXT_BUDGET_DIR}/scripts"
cp "${VERIFY}" "${NO_CONTEXT_BUDGET_DIR}/scripts/verify_skill.sh"
cp "${RESOLVE}" "${NO_CONTEXT_BUDGET_DIR}/scripts/resolve_bundled_root.sh"
chmod +x "${NO_CONTEXT_BUDGET_DIR}/scripts/resolve_bundled_root.sh"
cp -R "${SKILL_DIR}/fixtures" "${NO_CONTEXT_BUDGET_DIR}/fixtures"
cp "${SOURCE_SKILL}" "${NO_CONTEXT_BUDGET_DIR}/SKILL.md"
sed -i '' '/^## Context Budget Protocol$/,/^## Excellence Doctrine$/{
  /^## Excellence Doctrine$/!d
}' "${NO_CONTEXT_BUDGET_DIR}/SKILL.md" 2>/dev/null \
  || sed -i '/^## Context Budget Protocol$/,/^## Excellence Doctrine$/{
    /^## Excellence Doctrine$/!d
  }' "${NO_CONTEXT_BUDGET_DIR}/SKILL.md"
expect_fail "NO_CONTEXT_BUDGET" "Context Budget Protocol" bash "${NO_CONTEXT_BUDGET_DIR}/scripts/verify_skill.sh"
# Context-budget regression: covered by NO_CONTEXT_BUDGET above (PR 1) — do not duplicate strip fixture.

# --- Stripped effort-5 reviewer roster algorithm (total_slots = 6 block) ---
NO_EFFORT5_ROSTER_DIR="${TMPROOT}/no-effort5-roster"
mkdir -p "${NO_EFFORT5_ROSTER_DIR}/scripts"
cp "${VERIFY}" "${NO_EFFORT5_ROSTER_DIR}/scripts/verify_skill.sh"
cp "${RESOLVE}" "${NO_EFFORT5_ROSTER_DIR}/scripts/resolve_bundled_root.sh"
chmod +x "${NO_EFFORT5_ROSTER_DIR}/scripts/resolve_bundled_root.sh"
cp -R "${SKILL_DIR}/fixtures" "${NO_EFFORT5_ROSTER_DIR}/fixtures"
cp "${SOURCE_SKILL}" "${NO_EFFORT5_ROSTER_DIR}/SKILL.md"
sed -i '' '/^\*\*Decision algorithm (per PR)\*\*/,/^\*\*Building reviewer_configs (per PR):\*\*/{
  /^\*\*Building reviewer_configs (per PR):\*\*/!d
}' "${NO_EFFORT5_ROSTER_DIR}/SKILL.md" 2>/dev/null \
  || sed -i '/^\*\*Decision algorithm (per PR)\*\*/,/^\*\*Building reviewer_configs (per PR):\*\*/{
    /^\*\*Building reviewer_configs (per PR):\*\*/!d
  }' "${NO_EFFORT5_ROSTER_DIR}/SKILL.md"
expect_fail "NO_EFFORT5_ROSTER_ALGORITHM" "total_slots = 6" bash "${NO_EFFORT5_ROSTER_DIR}/scripts/verify_skill.sh"

# --- Replaced matched_specialists.append wiring ---
NO_MATCHED_APPEND_DIR="${TMPROOT}/no-matched-append"
mkdir -p "${NO_MATCHED_APPEND_DIR}/scripts"
cp "${VERIFY}" "${NO_MATCHED_APPEND_DIR}/scripts/verify_skill.sh"
cp "${RESOLVE}" "${NO_MATCHED_APPEND_DIR}/scripts/resolve_bundled_root.sh"
chmod +x "${NO_MATCHED_APPEND_DIR}/scripts/resolve_bundled_root.sh"
cp -R "${SKILL_DIR}/fixtures" "${NO_MATCHED_APPEND_DIR}/fixtures"
cp "${SOURCE_SKILL}" "${NO_MATCHED_APPEND_DIR}/SKILL.md"
sed -i '' 's/matched_specialists\.append/matched_specialists_broken/g' "${NO_MATCHED_APPEND_DIR}/SKILL.md" 2>/dev/null \
  || sed -i 's/matched_specialists\.append/matched_specialists_broken/g' "${NO_MATCHED_APPEND_DIR}/SKILL.md"
expect_fail "NO_MATCHED_SPECIALISTS_APPEND" "matched_specialists.append" bash "${NO_MATCHED_APPEND_DIR}/scripts/verify_skill.sh"

# --- Stripped The Algorithm subsection (Excellence Doctrine) ---
NO_ALGORITHM_DIR="${TMPROOT}/no-algorithm"
mkdir -p "${NO_ALGORITHM_DIR}/scripts"
cp "${VERIFY}" "${NO_ALGORITHM_DIR}/scripts/verify_skill.sh"
cp "${RESOLVE}" "${NO_ALGORITHM_DIR}/scripts/resolve_bundled_root.sh"
chmod +x "${NO_ALGORITHM_DIR}/scripts/resolve_bundled_root.sh"
cp -R "${SKILL_DIR}/fixtures" "${NO_ALGORITHM_DIR}/fixtures"
cp "${SOURCE_SKILL}" "${NO_ALGORITHM_DIR}/SKILL.md"
sed -i '' '/^### 4\. The Algorithm/,/^### 5\. Utility gate/{
  /^### 5\. Utility gate/!d
}' "${NO_ALGORITHM_DIR}/SKILL.md" 2>/dev/null \
  || sed -i '/^### 4\. The Algorithm/,/^### 5\. Utility gate/{
    /^### 5\. Utility gate/!d
  }' "${NO_ALGORITHM_DIR}/SKILL.md"
expect_fail "NO_ALGORITHM_SUBSECTION" "The Algorithm" bash "${NO_ALGORITHM_DIR}/scripts/verify_skill.sh"

# --- Dropped wait protocol ---
NO_WAIT_DIR="${TMPROOT}/no-wait"
mkdir -p "${NO_WAIT_DIR}/scripts"
cp "${VERIFY}" "${NO_WAIT_DIR}/scripts/verify_skill.sh"
cp "${RESOLVE}" "${NO_WAIT_DIR}/scripts/resolve_bundled_root.sh"
chmod +x "${NO_WAIT_DIR}/scripts/resolve_bundled_root.sh"
cp -R "${SKILL_DIR}/fixtures" "${NO_WAIT_DIR}/fixtures"
cp "${SOURCE_SKILL}" "${NO_WAIT_DIR}/SKILL.md"
sed -i '' '/get_command_or_subagent_output/d' "${NO_WAIT_DIR}/SKILL.md" 2>/dev/null \
  || sed -i '/get_command_or_subagent_output/d' "${NO_WAIT_DIR}/SKILL.md"
expect_fail "missing get_command_or_subagent_output" "get_command_or_subagent_output" bash "${NO_WAIT_DIR}/scripts/verify_skill.sh"

# --- Missing inline execute (execute_inline phase) ---
NO_INLINE_DIR="${TMPROOT}/no-inline"
mkdir -p "${NO_INLINE_DIR}/scripts"
cp "${VERIFY}" "${NO_INLINE_DIR}/scripts/verify_skill.sh"
cp "${RESOLVE}" "${NO_INLINE_DIR}/scripts/resolve_bundled_root.sh"
chmod +x "${NO_INLINE_DIR}/scripts/resolve_bundled_root.sh"
cp -R "${SKILL_DIR}/fixtures" "${NO_INLINE_DIR}/fixtures"
cp "${SOURCE_SKILL}" "${NO_INLINE_DIR}/SKILL.md"
sed -i '' 's/execute_inline/INLINE_PHASE_REMOVED/g' "${NO_INLINE_DIR}/SKILL.md" 2>/dev/null \
  || sed -i 's/execute_inline/INLINE_PHASE_REMOVED/g' "${NO_INLINE_DIR}/SKILL.md"
expect_fail "missing execute_inline" "execute_inline" bash "${NO_INLINE_DIR}/scripts/verify_skill.sh"

# --- Missing effort passthrough wiring ---
NO_EFFORT_DIR="${TMPROOT}/no-effort"
mkdir -p "${NO_EFFORT_DIR}/scripts"
cp "${VERIFY}" "${NO_EFFORT_DIR}/scripts/verify_skill.sh"
cp "${RESOLVE}" "${NO_EFFORT_DIR}/scripts/resolve_bundled_root.sh"
chmod +x "${NO_EFFORT_DIR}/scripts/resolve_bundled_root.sh"
cp -R "${SKILL_DIR}/fixtures" "${NO_EFFORT_DIR}/fixtures"
cp "${SOURCE_SKILL}" "${NO_EFFORT_DIR}/SKILL.md"
sed -i '' 's/\*\*not\*\* hardcoded 1/always hardcoded 1/g' "${NO_EFFORT_DIR}/SKILL.md" 2>/dev/null \
  || sed -i 's/\*\*not\*\* hardcoded 1/always hardcoded 1/g' "${NO_EFFORT_DIR}/SKILL.md"
expect_fail "missing effort passthrough" "hardcoded 1" bash "${NO_EFFORT_DIR}/scripts/verify_skill.sh"

# --- Missing PRIMARY/FALLBACK path labels ---
NO_PRIMARY_DIR="${TMPROOT}/no-primary"
mkdir -p "${NO_PRIMARY_DIR}/scripts"
cp "${VERIFY}" "${NO_PRIMARY_DIR}/scripts/verify_skill.sh"
cp "${RESOLVE}" "${NO_PRIMARY_DIR}/scripts/resolve_bundled_root.sh"
chmod +x "${NO_PRIMARY_DIR}/scripts/resolve_bundled_root.sh"
cp -R "${SKILL_DIR}/fixtures" "${NO_PRIMARY_DIR}/fixtures"
cp "${SOURCE_SKILL}" "${NO_PRIMARY_DIR}/SKILL.md"
sed -i '' 's/PRIMARY/DEFAULT_PATH/g' "${NO_PRIMARY_DIR}/SKILL.md" 2>/dev/null \
  || sed -i 's/PRIMARY/DEFAULT_PATH/g' "${NO_PRIMARY_DIR}/SKILL.md"
expect_fail "missing PRIMARY label" "PRIMARY" bash "${NO_PRIMARY_DIR}/scripts/verify_skill.sh"

# --- Missing execute_pending phase token ---
NO_PENDING_DIR="${TMPROOT}/no-pending"
mkdir -p "${NO_PENDING_DIR}/scripts"
cp "${VERIFY}" "${NO_PENDING_DIR}/scripts/verify_skill.sh"
cp "${RESOLVE}" "${NO_PENDING_DIR}/scripts/resolve_bundled_root.sh"
chmod +x "${NO_PENDING_DIR}/scripts/resolve_bundled_root.sh"
cp -R "${SKILL_DIR}/fixtures" "${NO_PENDING_DIR}/fixtures"
cp "${SOURCE_SKILL}" "${NO_PENDING_DIR}/SKILL.md"
sed -i '' 's/execute_pending/EXEC_PENDING_REMOVED/g' "${NO_PENDING_DIR}/SKILL.md" 2>/dev/null \
  || sed -i 's/execute_pending/EXEC_PENDING_REMOVED/g' "${NO_PENDING_DIR}/SKILL.md"
expect_fail "missing execute_pending" "execute_pending" bash "${NO_PENDING_DIR}/scripts/verify_skill.sh"

# --- Wrong Phase 4b heading ---
BAD_PHASE4B_DIR="${TMPROOT}/bad-phase4b"
mkdir -p "${BAD_PHASE4B_DIR}/scripts"
cp "${VERIFY}" "${BAD_PHASE4B_DIR}/scripts/verify_skill.sh"
cp "${RESOLVE}" "${BAD_PHASE4B_DIR}/scripts/resolve_bundled_root.sh"
chmod +x "${BAD_PHASE4B_DIR}/scripts/resolve_bundled_root.sh"
cp -R "${SKILL_DIR}/fixtures" "${BAD_PHASE4B_DIR}/fixtures"
cp "${SOURCE_SKILL}" "${BAD_PHASE4B_DIR}/SKILL.md"
sed -i '' 's/^## Phase 4b: Summarize and Ask Open Questions$/## Phase 4b: Summary Only/' "${BAD_PHASE4B_DIR}/SKILL.md" 2>/dev/null \
  || sed -i 's/^## Phase 4b: Summarize and Ask Open Questions$/## Phase 4b: Summary Only/' "${BAD_PHASE4B_DIR}/SKILL.md"
expect_fail "wrong Phase 4b heading" "Phase 4b: Summarize and Ask Open Questions" bash "${BAD_PHASE4B_DIR}/scripts/verify_skill.sh"

# --- Phase 6 before Step 9 ordering regression ---
BAD_ORDER_DIR="${TMPROOT}/bad-order"
mkdir -p "${BAD_ORDER_DIR}/scripts"
cp "${VERIFY}" "${BAD_ORDER_DIR}/scripts/verify_skill.sh"
cp "${RESOLVE}" "${BAD_ORDER_DIR}/scripts/resolve_bundled_root.sh"
chmod +x "${BAD_ORDER_DIR}/scripts/resolve_bundled_root.sh"
cp -R "${SKILL_DIR}/fixtures" "${BAD_ORDER_DIR}/fixtures"
cp "${SOURCE_SKILL}" "${BAD_ORDER_DIR}/SKILL.md"
sed -i '' '/Normative order.*Step 8.*Phase 6.*Step 9/d' "${BAD_ORDER_DIR}/SKILL.md" 2>/dev/null \
  || sed -i '/Normative order.*Step 8.*Phase 6.*Step 9/d' "${BAD_ORDER_DIR}/SKILL.md"
expect_fail "missing Phase6/Step9 ordering" "Normative order" bash "${BAD_ORDER_DIR}/scripts/verify_skill.sh"

# --- Missing Subagent Worktree Protocol ---
NO_WT_DIR="${TMPROOT}/no-worktree-protocol"
mkdir -p "${NO_WT_DIR}/scripts"
cp "${VERIFY}" "${NO_WT_DIR}/scripts/verify_skill.sh"
cp "${RESOLVE}" "${NO_WT_DIR}/scripts/resolve_bundled_root.sh"
chmod +x "${NO_WT_DIR}/scripts/resolve_bundled_root.sh"
cp -R "${SKILL_DIR}/fixtures" "${NO_WT_DIR}/fixtures"
cp "${SOURCE_SKILL}" "${NO_WT_DIR}/SKILL.md"
sed -i '' '/Subagent Worktree Protocol/,/Idempotent/d' "${NO_WT_DIR}/SKILL.md" 2>/dev/null \
  || sed -i '/Subagent Worktree Protocol/,/Idempotent/d' "${NO_WT_DIR}/SKILL.md"
expect_fail "missing worktree protocol" "Subagent Worktree Protocol" bash "${NO_WT_DIR}/scripts/verify_skill.sh"

# --- Broken suffix_map wiring (reviewer_configs review_file) ---
BAD_SUFFIX_DIR="${TMPROOT}/bad-suffix-map"
mkdir -p "${BAD_SUFFIX_DIR}/scripts"
cp "${VERIFY}" "${BAD_SUFFIX_DIR}/scripts/verify_skill.sh"
cp "${RESOLVE}" "${BAD_SUFFIX_DIR}/scripts/resolve_bundled_root.sh"
chmod +x "${BAD_SUFFIX_DIR}/scripts/resolve_bundled_root.sh"
cp -R "${SKILL_DIR}/fixtures" "${BAD_SUFFIX_DIR}/fixtures"
cp "${SOURCE_SKILL}" "${BAD_SUFFIX_DIR}/SKILL.md"
sed -i '' 's/suffix_map\[specialist\]/suffix_broken/g' "${BAD_SUFFIX_DIR}/SKILL.md" 2>/dev/null \
  || sed -i 's/suffix_map\[specialist\]/suffix_broken/g' "${BAD_SUFFIX_DIR}/SKILL.md"
expect_fail "broken suffix_map wiring" "suffix_map\\[specialist\\]" bash "${BAD_SUFFIX_DIR}/scripts/verify_skill.sh"

# --- Missing delegate-without-execute rejection ---
NO_DELEGATE_REJECT_DIR="${TMPROOT}/no-delegate-reject"
mkdir -p "${NO_DELEGATE_REJECT_DIR}/scripts"
cp "${VERIFY}" "${NO_DELEGATE_REJECT_DIR}/scripts/verify_skill.sh"
cp "${RESOLVE}" "${NO_DELEGATE_REJECT_DIR}/scripts/resolve_bundled_root.sh"
chmod +x "${NO_DELEGATE_REJECT_DIR}/scripts/resolve_bundled_root.sh"
cp -R "${SKILL_DIR}/fixtures" "${NO_DELEGATE_REJECT_DIR}/fixtures"
cp "${SOURCE_SKILL}" "${NO_DELEGATE_REJECT_DIR}/SKILL.md"
sed -i '' 's/--delegate-execute requires --execute/delegate execute pairing removed/g' "${NO_DELEGATE_REJECT_DIR}/SKILL.md" 2>/dev/null \
  || sed -i 's/--delegate-execute requires --execute/delegate execute pairing removed/g' "${NO_DELEGATE_REJECT_DIR}/SKILL.md"
expect_fail "missing delegate-execute reject" "--delegate-execute requires --execute" bash "${NO_DELEGATE_REJECT_DIR}/scripts/verify_skill.sh"

# --- Stale inline-not-implemented messaging regression ---
STALE_INLINE_DIR="${TMPROOT}/stale-inline"
mkdir -p "${STALE_INLINE_DIR}/scripts"
cp "${VERIFY}" "${STALE_INLINE_DIR}/scripts/verify_skill.sh"
cp "${RESOLVE}" "${STALE_INLINE_DIR}/scripts/resolve_bundled_root.sh"
chmod +x "${STALE_INLINE_DIR}/scripts/resolve_bundled_root.sh"
cp -R "${SKILL_DIR}/fixtures" "${STALE_INLINE_DIR}/fixtures"
cp "${SOURCE_SKILL}" "${STALE_INLINE_DIR}/SKILL.md"
printf '\nInline execute resume not implemented\n' >> "${STALE_INLINE_DIR}/SKILL.md"
expect_fail "stale inline-not-implemented" "stale inline-execute-not-implemented" bash "${STALE_INLINE_DIR}/scripts/verify_skill.sh"

# --- Implementer warn-only regression (realistic Persona Resolution mutation) ---
WARN_IMPL_DIR="${TMPROOT}/warn-implementer"
mkdir -p "${WARN_IMPL_DIR}/scripts"
cp "${VERIFY}" "${WARN_IMPL_DIR}/scripts/verify_skill.sh"
cp "${RESOLVE}" "${WARN_IMPL_DIR}/scripts/resolve_bundled_root.sh"
chmod +x "${WARN_IMPL_DIR}/scripts/resolve_bundled_root.sh"
cp -R "${SKILL_DIR}/fixtures" "${WARN_IMPL_DIR}/fixtures"
cp "${SOURCE_SKILL}" "${WARN_IMPL_DIR}/SKILL.md"
sed -i '' 's/Required (fail-fast):/Required (warn-only):/' "${WARN_IMPL_DIR}/SKILL.md" 2>/dev/null \
  || sed -i 's/Required (fail-fast):/Required (warn-only):/' "${WARN_IMPL_DIR}/SKILL.md"
expect_fail "implementer warn-only" "implementer persona must be fail-fast" bash "${WARN_IMPL_DIR}/scripts/verify_skill.sh"

# --- Memory dual-flush contradiction regression ---
DUAL_FLUSH_DIR="${TMPROOT}/dual-flush"
mkdir -p "${DUAL_FLUSH_DIR}/scripts"
cp "${VERIFY}" "${DUAL_FLUSH_DIR}/scripts/verify_skill.sh"
cp "${RESOLVE}" "${DUAL_FLUSH_DIR}/scripts/resolve_bundled_root.sh"
chmod +x "${DUAL_FLUSH_DIR}/scripts/resolve_bundled_root.sh"
cp -R "${SKILL_DIR}/fixtures" "${DUAL_FLUSH_DIR}/fixtures"
cp "${SOURCE_SKILL}" "${DUAL_FLUSH_DIR}/SKILL.md"
printf '\nupdate after Phase 4b (and Phase 6 when execute completes)\n' >> "${DUAL_FLUSH_DIR}/SKILL.md"
expect_fail "memory dual-flush contradiction" "memory timing contradiction" bash "${DUAL_FLUSH_DIR}/scripts/verify_skill.sh"

# --- Final Report bullet floor regression ---
LOW_BULLETS_DIR="${TMPROOT}/low-bullets"
mkdir -p "${LOW_BULLETS_DIR}/scripts"
cp "${VERIFY}" "${LOW_BULLETS_DIR}/scripts/verify_skill.sh"
cp "${RESOLVE}" "${LOW_BULLETS_DIR}/scripts/resolve_bundled_root.sh"
chmod +x "${LOW_BULLETS_DIR}/scripts/resolve_bundled_root.sh"
cp -R "${SKILL_DIR}/fixtures" "${LOW_BULLETS_DIR}/fixtures"
cp "${SOURCE_SKILL}" "${LOW_BULLETS_DIR}/SKILL.md"
sed -i '' '/^6\. \*\*Design document\*\*/,/^15\. \*\*/d' "${LOW_BULLETS_DIR}/SKILL.md" 2>/dev/null \
  || sed -i '/^6\. \*\*Design document\*\*/,/^15\. \*\*/d' "${LOW_BULLETS_DIR}/SKILL.md"
expect_fail "Final Report bullet floor" "Final Report needs" bash "${LOW_BULLETS_DIR}/scripts/verify_skill.sh"

# --- Missing bundled_skills_root (no HOME bundle and no repo fixture) ---
BROKEN_HOME="${TMPROOT}/broken-home"
NO_FIXTURE_DIR="${TMPROOT}/no-fixture-repo"
mkdir -p "${BROKEN_HOME}/.grok" "${NO_FIXTURE_DIR}/scripts"
cp "${SOURCE_SKILL}" "${NO_FIXTURE_DIR}/SKILL.md"
cp "${VERIFY}" "${NO_FIXTURE_DIR}/scripts/verify_skill.sh"
cp "${RESOLVE}" "${NO_FIXTURE_DIR}/scripts/resolve_bundled_root.sh"
chmod +x "${NO_FIXTURE_DIR}/scripts/resolve_bundled_root.sh"
expect_fail "missing bundled_skills_root" "no bundled skills root found" \
  env -u BUNDLED_SKILLS_ROOT HOME="${BROKEN_HOME}" bash "${NO_FIXTURE_DIR}/scripts/verify_skill.sh"

# --- Empty required persona via HOME override + fixture path ---
FIXTURE_HOME="${TMPROOT}/fixture-home"
FIXTURE_BUNDLED="${FIXTURE_HOME}/.grok/bundled/skills"
mkdir -p "${FIXTURE_BUNDLED}/shared/personas" "${FIXTURE_BUNDLED}/implement/scripts"
cp "${BUNDLED_SRC}/implement/scripts/memory.py" "${FIXTURE_BUNDLED}/implement/scripts/"
cp "${BUNDLED_SRC}/implement/SKILL.md" "${FIXTURE_BUNDLED}/implement/SKILL.md"
for persona in design-doc-writer design-doc-reviewer reviewer security-auditor implementer; do
  cp "${BUNDLED_SRC}/shared/personas/${persona}.md" "${FIXTURE_BUNDLED}/shared/personas/${persona}.md"
done
: > "${FIXTURE_BUNDLED}/shared/personas/design-doc-writer.md"
expect_fail "empty persona" "persona empty" env HOME="${FIXTURE_HOME}" BUNDLED_SKILLS_ROOT="${FIXTURE_BUNDLED}" bash "${VERIFY}"

# --- memory.py: non-git cwd with HOME set → exit 0 ---
MEMORY_HELPER="${BUNDLED_SRC}/implement/scripts/memory.py"
NON_GIT_DIR="$(mktemp -d)"
trap 'rm -rf "${TMPROOT}" "${NON_GIT_DIR}"' EXIT
(
  cd "${NON_GIT_DIR}"
  python3 "${MEMORY_HELPER}" snapshot >/dev/null
) || fail "non-git cwd snapshot should exit 0 with HOME set"
pass "memory.py snapshot exit 0 in non-git cwd"

# --- memory.py: unreadable cwd + unset HOME → exit 2 (best-effort) ---
UNREADABLE_DIR="$(mktemp -d)"
chmod 000 "${UNREADABLE_DIR}"
if (
  cd "${UNREADABLE_DIR}" 2>/dev/null
  env -u HOME python3 "${MEMORY_HELPER}" snapshot >/dev/null 2>&1
); then
  echo "SKIP: could not reproduce WorkspaceIdError exit 2 in this environment" >&2
else
  pass "memory.py snapshot fails with unreadable cwd and unset HOME"
fi
chmod 700 "${UNREADABLE_DIR}" 2>/dev/null || true

echo ""
echo "All negative verify_skill tests passed."